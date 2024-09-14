INCL = -I.
CFLAGS = -Wall -O3 $(INCL)
UNAME = $(shell uname)
CC = gcc
LD = gcc
LDFLAGS =
CONS_LDFLAGS = -lX11

65816_OBJS = 65816.o 65816_engine.o memio_driver.o
65816_TARGET = 65816
RV_OBJS = randvideo.o memio_driver.o
RV_TARGET = randvideo
KE_OBJS = kbdecho.o memio_driver.o
KE_TARGET = kbdecho
CONS_OBJS = console.o memio_driver.o
CONS_TARGET = console

all: $(65816_TARGET) $(RV_TARGET) $(KE_TARGET) $(CONS_TARGET)

$(65816_TARGET): $(65816_OBJS)

	acme e4.a
	$(LD) $(65816_OBJS) -o $(65816_TARGET) $(LDFLAGS)

$(RV_TARGET): $(RV_OBJS)

	$(LD) $(RV_OBJS) -o $(RV_TARGET) $(LDFLAGS)

$(KE_TARGET): $(KE_OBJS)

	$(LD) $(KE_OBJS) -o $(KE_TARGET) $(LDFLAGS)

$(CONS_TARGET): $(CONS_OBJS)

	$(LD) $(CONS_OBJS) -o $(CONS_TARGET) $(CONS_LDFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) -c $<

clean:
	rm -f *.o
	rm -f *~
	rm -f $(RV_TARGET)
	rm -f $(CONS_TARGET)
