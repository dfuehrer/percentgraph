#include <iostream>
#include <locale>
#include <filesystem>
#include <cstring>
#include <cstdio>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>

#define ARRAY_LENGTH(arr)   ((sizeof arr) / (sizeof arr[0]))

int main(const int argc, const char * const argv[]){
    std::locale::global(std::locale(""));
    if(argc < 2){
        std::cerr << "you needa give socket path\n";
        return 1;
    }else if(argc > 2){
        std::cerr << "only using first argument for socket path\n";
    }
    const char * socketName = argv[1];
    if(!std::filesystem::exists(socketName)){
        std::cerr << "socket " << socketName << " does not exist" << std::endl;
        return 2;
    }
    struct sockaddr_un socketAddr;
    std::memset(&socketAddr, 0, sizeof socketAddr);
    socketAddr.sun_family = AF_UNIX;
    std::strncpy(socketAddr.sun_path, socketName, (sizeof socketAddr.sun_path) - 1);
    //std::cerr << "going to open " << socketAddr.sun_path << std::endl;

    int data_socket = socket(socketAddr.sun_family, SOCK_STREAM, 0);
    if (data_socket == -1){
        std::perror("open socket");
        std::exit(EXIT_FAILURE);
    }
    ssize_t ret = connect(data_socket, (const struct sockaddr *) &socketAddr, sizeof socketAddr);
    if (ret == -1){
        std::perror("connect to socket");
        std::exit(EXIT_FAILURE);
    }
    //std::cerr << "just opened " << socketName << std::endl;

    // dont need to send anything to server, connecting to socket is enough
    int lineLen = 0;
    //std::cerr << "gonna try to read\n";
    ret = recv(data_socket, &lineLen, sizeof lineLen, 0);
    if (ret == -1){
        std::perror("read len from server");
        std::exit(EXIT_FAILURE);
    }
    //std::cerr << "should read " << lineLen << " chars" << std::endl;
    wchar_t * line = new wchar_t[lineLen + 1];
    ret = recv(data_socket, line, lineLen * sizeof (wchar_t), 0);
    if (ret == -1){
        std::perror("read line from server");
        std::exit(EXIT_FAILURE);
    }
    line[lineLen] = L'\000';
    //std::cerr << "just read:\n";
    //std::wcout << L"'" << line << L"'\n";
    std::wcout << line << std::endl;
    delete[] line;

    //std::cerr << "closing socket\n";
    close(data_socket);

    return 0;
}
