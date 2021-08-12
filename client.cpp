#include <iostream>
#include <fstream>
#include <string>
#include <locale>
#include <filesystem>

int main(const int argc, const char * const argv[]){
    std::locale::global(std::locale(""));
    if(argc < 3){
        std::cerr << "you needa give fifoIn fifoOut\n";
        return 1;
    }else if(argc > 3){
        std::cerr << "only using first 2 arguments for fifoIn fifoOut\n";
    }
    const char * finName = argv[1];
    const char * foutName = argv[2];
    if(!std::filesystem::exists(foutName)){
        return 2;
    }
    std::ofstream fout(foutName);
    //std::wcout << L"just opened " << foutName << '\n';
    std::wifstream fin(finName);
    //std::wcout << L"just opened " << finName << '\n';

    const char tosend[] = "hey wake up dummy";
    //std::cerr << "trying to send '" << tosend << "'\n";
    fout << tosend << std::endl;

    std::wstring line;
    //std::cerr << "gonna try to read\n";
    std::getline(fin, line);
    //std::cerr << "just read:\n";
    //std::wcout << L"'" << line << L"'\n";
    //std::wcout << line << std::endl;
    std::wcout << line;

    fout << "handshake" << std::endl;
    //std::cerr << "gonna free\n";
    fin.close();
    fout.close();
    return 0;
}
