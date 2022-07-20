#include <iostream>
#include <fstream>
#include <string>
#include <array>
#include <locale>
#include "drawille-plusplus/drawille.hpp"
#include <cstdio>

template <typename T, size_t N>
std::istream & operator>>(std::istream & stream, std::array<T, N> & arr){
    for(auto & num: arr){
        stream >> num;
    }
    return stream;
}

template <typename T, size_t N>
std::ostream & operator<<(std::ostream & stream, const std::array<T, N> & arr){
    typename std::array<T, N>::const_iterator it = arr.cbegin();
    for(; it+1 != arr.cend(); ++it){
        stream << *it << ' ';
    }
    stream << *it << '\n';
    return stream;
}

// TODO get rid of the reading and writing to a file and instead just hold the data till given an interrupt or something
template <typename T, size_t numSave, size_t numPercents>
class PercentGraph{
    public:
        using percent_t = unsigned int;
        PercentGraph(std::string filename): 
            filename(filename){
            std::locale::global(std::locale(""));

        }
        // read in the data, fill the percents, return the data
        std::array<T, numSave> readDatas(){
            std::ifstream istore(filename);
            std::array<T, numSave> read;
            istore >> read;
            for(auto & percent: percents){
                istore >> percent;
            }
            istore.close();
            return read;
        }
        // draw the graph and give the percent after
        void outputPercents(std::array<percent_t, numPercents> current){
            currentPercents = current;
            Drawille::Canvas canvas(4, 1);
            for(auto cur: current){
                canvas.set(percentsStored, 3 - cur / 25);
            }
            for(int i = 0; i < percents.size(); i++){
                for(auto num: percents[i]){
                    canvas.set(6 - i, 3 - num / 25);
                }
            }
            canvas.draw(std::wcout);
            /* std::wcout << "\10\10\10\10" << std::format("{3d}%\n", percent); */
            std::wprintf(L"%3d%%\n", current);
        }
        void outputPercents(percent_t current){
            //std::array<percent_t, numPercents> percent = {current};
            //outputPercents(percent);
            outputPercents((std::array<percent_t, numPercents>) {current});
        }
        // save the datas back into the file
        void saveDatas(std::array<T, numSave> toSave){
            std::ofstream store(filename);
            store << toSave;
            store << currentPercents << '\n';
            for(typename std::array<std::array<percent_t, numPercents>, percentsStored>::const_iterator it = percents.cbegin(); it+1 != percents.cend(); ++it){
                store << *it;
                //std::cout << *it;
            }
            store.close();
        }
    private:
        static constexpr size_t percentsStored = 7;
        std::string filename;
        std::array<std::array<percent_t, numPercents>, percentsStored> percents;
        std::array<percent_t, numPercents> currentPercents;
};
