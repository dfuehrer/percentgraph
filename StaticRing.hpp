#ifndef STATIC_RING_HPP
#define STATIC_RING_HPP

#include <array>

template <typename T>
struct ListType{
    T data;
    ListType * next;
    ListType * prev;
};

template <typename T>
struct ListIterator{
    typedef ListType<T>     Node_t;
    typedef ListIterator<T> Iterator_t;

    ListIterator(bool ih=false): node(), isHead(ih) {}
    explicit ListIterator(Node_t * n, bool ih=false): node(n), isHead(ih) {}

    T & operator*() const {
        return node->data;
    }
    T * operator->() const {
        return &node->data;
    }

    Iterator_t & operator++(){
        node = node->next;
        isHead = false;
        return *this;
    }
    Iterator_t operator++(int){
        Iterator_t tmp = *this;
        node = node->next;
        isHead = false;
        return tmp;
    }
    Iterator_t & operator--(){
        node = node->prev;
        isHead = false;
        return *this;
    }
    Iterator_t operator--(int){
        Iterator_t tmp = *this;
        node = node->prev;
        isHead = false;
        return tmp;
    }

    friend bool operator==(const Iterator_t & left, const Iterator_t & right){
        return (left.node == right.node) && (left.isHead == right.isHead);
    }
    friend bool operator!=(const Iterator_t & left, const Iterator_t & right){
        //return (left.node != right.node) || (left.isHead != right.isHead);
        return !(left == right);
    }

    Node_t * node;

    private:
    bool isHead;
};


template <typename T, std::size_t N>
class StaticRing{
public:
    typedef ListType<T> Node_t;
    typedef ListIterator<T> Iterator_t;

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
    //StaticRing(std::array<Node_t, N> data): head(dataarray->data){
    //    for(int i = 0; i < N-1; ++i){
    //        dataarray[i].next = &dataarray[i+1];
    //        dataarray[i].next->prev = &dataarray[i];
    //        dataarray[i].data = data[i];
    //    }
    //    dataarray[N-1].next = head;
    //    head->prev = &dataarray[N-1];
    //    head->prev->data = data[N-1];
    //}
    //void fill(std::array<Node_t, N> data){
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
    const Node_t * const getHead() const{
        return head;
    }
    Iterator_t begin(){
        return Iterator_t(head, true);
    }
    const Iterator_t begin() const{
        return Iterator_t(head, true);
    }
    Iterator_t end(){
        //return Iterator_t(head->prev);
        return Iterator_t(head, false);
    }
    const Iterator_t end() const{
        //return Iterator_t(head->prev);
        return Iterator_t(head, false);
    }
private:
    std::array<Node_t, N> dataarray;
    //Node_t dataarray[N];
    Node_t * head;
};



#endif // STATIC_RING_HPP
