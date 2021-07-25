#include <array>

template <typename T>
struct ListType{
    T data;
    ListType * next;
    ListType * prev;
};

//template <typename T, std::size_t N>
//class StaticList{
//    public:
//        StaticList():
//            head(dataarray),
//            tail(dataarray + N){
//        }
//        void move(ListType<T> * current, ListType<T> * desired){
//            if(current == desired)
//                return;
//            if(desired != nullptr){
//                pop(current);
//                insert(current, desired);
//            }
//        }
//    private:
//        //std::array<ListType<T>, N> dataarray;
//        ListType<T> dataarray[N];
//        T * head;
//        T * tail;
//
//        void insert(ListType<T> * current, ListType<T> * desired){
//            current->next = desired;
//            current->prev = desired->prev;
//            desired->prev->next = current;
//            desired->prev = current;
//        }
//        ListType<T> * const pop(const ListType<T> * const current){
//            if(current->prev)
//                current->prev->next = current->next;
//            else
//                head = current->next;
//            if(current->next)
//                current->next->prev = current->prev;
//            else
//                tail = current->prev;
//            return current;
//        }
//        ListType<T> * const popForward(const ListType<T> ** const current_ptr){
//            //current->prev->next = current->next;
//            //current->next->prev = current->prev;
//            ListType<T> * current = *current_ptr;
//            *current_ptr = (*current_ptr)->next;
//            (*current_ptr)->prev = current->prev;
//            return current;
//        }
//        ListType<T> * const popBackward(const ListType<T> ** const current_ptr){
//            //current->prev->next = current->next;
//            //current->next->prev = current->prev;
//            ListType<T> * current = *current_ptr;
//            *current_ptr = (*current_ptr)->prev;
//            (*current_ptr)->next = current->next;
//            return current;
//        }
//};

template <typename T, std::size_t N>
class StaticRing{
public:
    StaticRing(): head(dataarray.data()){
        for(int i = 0; i < N-1; ++i){
            dataarray[i].next = &dataarray[i+1];
            dataarray[i].next->prev = &dataarray[i];
            // hopefully = 0 means something for type T
            for(auto & data: dataarray[i].data)
                data = 0;
        }
        dataarray[N-1].next = head;
        head->prev = &dataarray[N-1];
    }
    //StaticRing(std::array<ListType<T>, N> data): head(dataarray->data){
    //    for(int i = 0; i < N-1; ++i){
    //        dataarray[i].next = &dataarray[i+1];
    //        dataarray[i].next->prev = &dataarray[i];
    //        dataarray[i].data = data[i];
    //    }
    //    dataarray[N-1].next = head;
    //    head->prev = &dataarray[N-1];
    //    head->prev->data = data[N-1];
    //}
    //void fill(std::array<ListType<T>, N> data){
    //    for(int i = 0; i < N; ++i){
    //        dataarray[i].data = data[i];
    //    }
    //}
    void setTail(T data){
        head->data = data;
        head = head->next;
    }
    void setHead(T data){
        head = head->prev;
        head->data = data;
    }
    std::size_t size() const{
        return N;
    }
    const ListType<T> * const getHead() const{
        return head;
    }
private:
    std::array<ListType<T>, N> dataarray;
    //ListType<T> dataarray[N];
    ListType<T> * head;
};
