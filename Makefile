SRC = client.cpp
DESTDIR=~
PREFIX=/.local

dumbclient: $(SRC)
	$(CXX) $(SRC) -o $@

.PHONY: clean install

clean:
	rm -f dumbclient $(OBJ)

install: dumbclient
	mkdir -p ${DESTDIR}${PREFIX}/bin
	cp -f dumbclient ${DESTDIR}${PREFIX}/bin
	chmod 755 ${DESTDIR}${PREFIX}/bin/dumbclient

