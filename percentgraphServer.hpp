#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <array>
#include <filesystem>
#include <functional>
#include <locale>
#include "drawille.hpp"
#include "StaticRing.hpp"
#include <cstdio>
#include <csignal>
#include <cstring>
//#include <cstdlib>
#include <sys/stat.h>
#include <sys/types.h>

namespace fs = std::filesystem;

// TODO maybe convert this to be something you could just build and use as a dumber server that works for all situations with smarter clients
//  right now this is able to work with simple dumb clients that talk to smart servers
template <typename T, size_t numSave, size_t numPercents>
class PercentGraphServer{
public:
    using percent_t = unsigned int;
    using clientRequestFunc_t = void(void);
    bool cleanExit;

    // file base is the directory + the start of the file name to use for the fifo files
    PercentGraphServer(std::string filebase): filebase(filebase), save{}, cleanExit(false), run(true){
        // i thought small string optimizations should statically allocate enough but i guess they dont allocate the necessary amount up front
        if(buffer.capacity() < bufferSize){
            std::cerr << "buffer capacity was " << buffer.capacity() << " so i had to reserve " << bufferSize << "\n";
            buffer.reserve(bufferSize);
        }


        std::locale::global(std::locale(""));
        // use the file base to create a temp name
        //fifoIn  = filebase + "fifoInXXXXXX";
        //fifoOut = filebase + "fifoOutXXXXXX";
        //mktemp(fifoIn.data());
        //mktemp(fifoOut.data());
        fifoIn  = filebase + "fifoIn";
        fifoOut = filebase + "fifoOut";
        // create the directory that these files are in and set the restricted deletion flag
        fs::path basedir = fs::path(filebase).remove_filename();
        fs::create_directory(basedir);
        fs::permissions(basedir, fs::perms::sticky_bit, fs::perm_options::add);

        // make the fifo files for the client to connect to
        mkfifo(fifoIn .c_str(), 0600);
        mkfifo(fifoOut.c_str(), 0600);
    }
    // this will do the necessary cleanup if the program exits on its own
    ~PercentGraphServer(){
        cleanup();
    }

    // get the last saved datas for use in the current calculation
    const std::array<T, numSave> getDatas() const{
        return save;
    }
    // draw the graph and give the percent after
    const std::wstring getPercents(std::array<percent_t, numPercents> current){
        //currentPercents = current;
        percents.setHead(current);
        Drawille::Canvas canvas(4, 1);
        //for(auto cur: current){
        //    canvas.set(percentsStored, 3 - cur / 25);
        //}

        // TODO add iterators to StaticRing and use this with iterators
        //for(int i = 0; i < percents.size(); i++){
        //    for(auto num: percents[i]){
        //        canvas.set(6 - i, 3 - num / 25);
        //    }
        //}
        int i = 0;
        for(const ListType<std::array<percent_t, numPercents>> * percent_ptr = percents.getHead(); percent_ptr->next != percents.getHead(); percent_ptr = percent_ptr->next, ++i){
            for(auto num: percent_ptr->data){
                canvas.set(6 - i, 3 - num / 25);
            }
        }
        std::wostringstream canvasStream;
        canvas.draw(canvasStream);
        //std::wcout << canvasStream.str();
        wchar_t buff[buffer.capacity()];
        std::wcsncpy(buff, canvasStream.str().c_str(), percentsStored/2);
        std::swprintf(buff + percentsStored/2, buffer.capacity() - percentsStored/2, L"%3d%%", current);
        buffer.assign(buff);
        return (const std::wstring) buffer;
    }
    // overloading so that if you only have 1 value you dont have to construct the array
    void getPercents(percent_t current){
        //std::array<percent_t, numPercents> percent = {current};
        //getPercents(percent);
        getPercents((std::array<percent_t, numPercents>) {current});
    }
    // save the current datas back into save
    void saveDatas(std::array<T, numSave> toSave){
        save = toSave;
        //percents.setHead(currentPercents);
    }
    // give funtion to call when client talks to server
    // this function should do things and eventually call getPercents to fill the buffer
    void onClientRequest(std::function<clientRequestFunc_t> func){
        onClientRequestFunc = func;
    }
    void runServer(std::function<clientRequestFunc_t> func){
        onClientRequest(func);
        runServer();
    }
    void runServer(){
        std::string inLine;
        while(run){
            // open fifo files
            std::ifstream fin(fifoIn);
            //std::cerr << "just opened " << fifoIn << '\n';
            std::wofstream fout(fifoOut);
            //std::cerr << "just opened " << fifoOut << '\n';
            // get request from client
            // TODO check the request
            cleanExit = false;
            if(std::getline(fin, inLine)){
                // call func
                onClientRequestFunc();
                // send back the buffer
                //std::wcout << L"sending " << buffer << L"\n";
                fout << buffer << std::endl;
                // try to get handshake
                // TODO check the handshake
                if(std::getline(fin, inLine)){
                    cleanExit = true;
                    //std::cerr << "got: " << inLine << std::endl;
                }
            }
            // close fifo files
            fin.close();
            fout.close();
        }
    }
    void cleanup() {
        // TODO delete the fifo files
        std::cerr << "trying to clean up: removing fifo files" << std::endl;
        fs::remove(fifoIn);
        fs::remove(fifoOut);
    }
    void stopRunning(){
        run = false;
        // TODO i was hoping i could open the files and itd be ok but that doesnt work
        // maybe remove them here? that seems dumb but

        //std::cerr << "want to open files to end this" << std::endl;
        //std::ofstream fin(fifoIn);
        //std::cerr << "just opened " << fifoIn  << " so i could close it\n";
        //std::wifstream fout(fifoOut);
        //std::cerr << "just opened " << fifoOut << " so i could close it\n";
        //fin.close();
        //fout.close();
    }
private:
    //static constexpr size_t percentsStored = 7;
    static constexpr size_t percentsStored = 8;
    std::string filebase;
    std::string fifoIn;
    std::string fifoOut;
    std::array<T, numSave> save;
    bool run;
    //std::array<std::array<percent_t, numPercents>, percentsStored> percents;
    StaticRing<std::array<percent_t, numPercents>, percentsStored> percents;
    //std::array<percent_t, numPercents> currentPercents;
    //std::array<wchar_t, (percentsStored+1)/2+7> buffer;
    //std::array<wchar_t, percentsStored/2+7> buffer;
    std::wstring buffer;
    static constexpr std::wstring::size_type bufferSize = percentsStored/2+7;
    std::function<clientRequestFunc_t> onClientRequestFunc;

};

