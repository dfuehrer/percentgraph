#ifndef PERCENT_GRAPH_SERVER
#define PERCENT_GRAPH_SERVER

#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <array>
#include <filesystem>
#include <functional>
#include <locale>
#include "drawille-plusplus/drawille.hpp"
#include "StaticRing.hpp"
#include <cstdio>
#include <csignal>
#include <cstring>
//#include <cstdlib>
#include <unistd.h>
#include <sys/stat.h>
//#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>

#ifndef NUM_PERCENTS_STORED
#define NUM_PERCENTS_STORED 8
#endif // NUM_PERCENTS_STORED

namespace fs = std::filesystem;

std::pair<char, double> rescaleData(long data);
std::string getCacheDir(std::string dirs);

// TODO maybe convert this to be something you could just build and use as a dumber server that works for all situations with smarter clients
//  right now this is able to work with simple dumb clients that talk to smart servers
template <typename T, std::size_t numSave, std::size_t numGraphs, std::size_t numPercents>
class PercentGraphServer{
public:
    using percent_t = unsigned int;
    using stored_t = T;
    using clientRequestFunc_t = void(void);
    static constexpr std::size_t numGraphPercents = numGraphs;
    static constexpr std::size_t numPrintPercents = numPercents;
    bool cleanExit;

    // file base is the directory + the start of the file name to use for the fifo files
    PercentGraphServer(std::string filebase, std::array<wchar_t, numPercents> units): units(units), save{}, cleanExit(false), run(true){
        // i thought small string optimizations should statically allocate enough but i guess they dont allocate the necessary amount up front
        if(buffer.capacity() < bufferSize){
            std::cerr << "buffer capacity was " << buffer.capacity() << " so i had to reserve " << bufferSize << "\n";
            buffer.reserve(bufferSize);
        }

        delimeters.fill(L' ');


        std::locale::global(std::locale(""));
        // use the file base to create a temp name
        //fifoIn  = filebase + "fifoInXXXXXX";
        //fifoOut = filebase + "fifoOutXXXXXX";
        //mktemp(fifoIn.data());
        //mktemp(fifoOut.data());
        socketName  = filebase + ".sock";
        // create the directory that these files are in and set the restricted deletion flag
        fs::path basedir = fs::path(filebase).remove_filename();
        fs::create_directory(basedir);
        fs::permissions(basedir, fs::perms::sticky_bit, fs::perm_options::add);

        // create the socket
        std::memset(&socketAddr, 0, sizeof socketAddr);
        socketAddr.sun_family = AF_UNIX;
        std::strncpy(socketAddr.sun_path, socketName.c_str(), (sizeof socketAddr.sun_path) - 1);
        connection_socket = socket(socketAddr.sun_family, SOCK_STREAM, 0);
    }
    PercentGraphServer(std::string filebase, const wchar_t unit=L'%'): PercentGraphServer(filebase, units){
        units.fill(unit);
    }
    // this will do the necessary cleanup if the program exits on its own
    ~PercentGraphServer(){
        cleanup();
    }

    // get the last saved datas for use in the current calculation
    const std::array<stored_t, numSave> getDatas() const{
        return save;
    }
    void setDelimeters(std::array<wchar_t, numPercents> delim){
        delimeters = delim;
    }
    // draw the graph and give the percent after
    const std::wstring setPercents(std::array<percent_t, numGraphs> currentGraphs, std::array<stored_t, numPercents> currentPercents){
        // TODO prolly can replace this with an algorithm
        for(percent_t & percent: currentGraphs){
            if(percent > 100)
                percent = 100;
        }
        percents.setHead(currentGraphs);
        Drawille::Canvas canvas(4, 1);

        // TODO add iterators to StaticRing and use this with iterators
        int i = 0;
        for(std::array<percent_t, numGraphs> percent_arr: percents){
            for(percent_t percent: percent_arr){
                canvas.set(7 - i, 3 - percent / 25);
            }
            ++i;
        }
        std::wostringstream canvasStream;
        canvas.draw(canvasStream);
        //std::wcout << canvasStream.str();
        wchar_t buff[buffer.capacity()];
        wchar_t * buff_ptr = buff + percentsStored/2;
        //std::size_t len = buffer.capacity() - percentsStored/2;
        std::size_t len = 1 + 4 + 1 + 1;
        int added = 0;
        std::wcsncpy(buff, canvasStream.str().c_str(), percentsStored/2);
        for(i = 0; i < numPercents; ++i, buff_ptr += added){
            if(units[i] == L'%'){
                added = std::swprintf(buff_ptr, len, L"%lc%3d%%", delimeters[i], currentPercents[i]);
            }else{
                auto [scale, number] = rescaleData(currentPercents[i]);
                added = std::swprintf(buff_ptr, len + 1, L"%lc%4.3g%c%lc", delimeters[i], number, scale, units[i]);
            }
        }
        buffer.assign(buff);
        return (const std::wstring) buffer;
    }
    // overloading so that if you only have 1 value you dont have to construct the array
    const std::wstring setPercents(std::array<percent_t, numGraphs> currentGraphs, stored_t currentPercent){
        return setPercents(currentGraphs, (std::array<stored_t, numPercents>) {currentPercent});
    }
    const std::wstring setPercents(percent_t currentGraph, std::array<stored_t, numPercents> currentPercents){
        return setPercents((std::array<percent_t, numGraphs>) {currentGraph}, currentPercents);
    }
    const std::wstring setPercents(percent_t currentGraph, stored_t currentPercent){
        return setPercents((std::array<percent_t, numGraphs>) {currentGraph}, (std::array<stored_t, numPercents>) {currentPercent});
    }
    const std::wstring setPercents(percent_t currentGraph){
        return setPercents(currentGraph, (stored_t) currentGraph);
    }
    // save the current datas back into save
    void saveDatas(std::array<stored_t, numSave> toSave){
        save = toSave;
    }
    // give funtion to call when client talks to server
    // this function should do things and eventually call setPercents to fill the buffer
    void onClientRequest(std::function<clientRequestFunc_t> func){
        onClientRequestFunc = func;
    }
    void runServer(std::function<clientRequestFunc_t> func){
        onClientRequest(func);
        runServer();
    }
    void runServer(){
        std::string inLine;
        ssize_t ret = bind(connection_socket, (const struct sockaddr *) &socketAddr, sizeof socketAddr);
        if (ret == -1){
            std::perror("bind socket");
            cleanup();
            std::exit(EXIT_FAILURE);
        }
        // prepare for connections, set backlog size to 10
        ret = listen(connection_socket, 10);
        if (ret == -1){
            std::perror("listen on socket");
            cleanup();
            std::exit(EXIT_FAILURE);
        }
        std::cerr << "ready for connections\n";
        while(run){
            cleanExit = false;
            // open socket
            // accepting socket connection good enough, dont need to recieve anything from client
            int data_socket = accept(connection_socket, NULL, NULL);
            if (data_socket == -1){
                std::perror("accept on socket");
                cleanup();
                std::exit(EXIT_FAILURE);
            }
            // call func
            onClientRequestFunc();
            // send back the buffer
            //std::wcout << L"sending " << buffer.c_str() << L"\n";
            int bufsize = buffer.size();
            ret = send(data_socket, &bufsize, sizeof bufsize, 0);
            if (ret == -1){
                std::perror("send size to client");
                close(data_socket);
                cleanup();
                std::exit(EXIT_FAILURE);
            }
            ret = send(data_socket, buffer.c_str(), bufsize * sizeof (std::wstring::value_type), 0);
            // close socket for this client
            close(data_socket);
        }
        close(connection_socket);
    }
    void cleanup() {
        std::cerr << "trying to clean up: removing socket " << socketName << std::endl;
        fs::remove(socketName);
    }
    void stopRunning(){
        run = false;
        // maybe remove them here? that seems dumb but

        shutdown(connection_socket, SHUT_RDWR);
        close(connection_socket);
    }
private:
    //static constexpr size_t percentsStored = 7;
    static constexpr size_t percentsStored = 8;
    struct sockaddr_un socketAddr;
    int connection_socket;
    std::string socketName;
    //std::ifstream fin;
    //std::wofstream fout;
    std::array<stored_t, numSave> save;
    std::array<wchar_t, numPercents> units;
    std::array<wchar_t, numPercents> delimeters;
    bool run;
    //std::array<std::array<percent_t, numGraphs>, percentsStored> percents;
    StaticRing<std::array<percent_t, numGraphs>, percentsStored> percents;
    //std::array<wchar_t, (percentsStored+1)/2+7> buffer;
    //std::array<wchar_t, percentsStored/2+7> buffer;
    std::wstring buffer;
    //static constexpr std::wstring::size_type bufferSize = percentsStored/2+7;
    static constexpr std::wstring::size_type bufferSize = percentsStored/2 + (1+4+1+1)*numPercents + 1;
    std::function<clientRequestFunc_t> onClientRequestFunc;

};

// TODO make an option to use data sizes (1024 instead of 1000)
std::pair<char, double> rescaleData(long data){
    char scales[] = " kMGTPEZY";    // metric unit scales starting from 0
    double output = data;
    int i;
    for(i = 0; output >= 1000; ++i){
        output /= 1000;
    }

    return {scales[i], output};
};

std::string getCacheDir(std::string dirs){
    std::string HOME = std::getenv("HOME");
    std::string XDG_CACHE_HOME = std::getenv("XDG_CACHE_HOME");
    if(XDG_CACHE_HOME == ""){
        XDG_CACHE_HOME = HOME + "/.cache";
    }

    std::string cacheDir = XDG_CACHE_HOME + "/" + dirs;
    fs::create_directories(cacheDir);

    return cacheDir;
}

#endif  // PERCENT_GRAPH_SERVER
