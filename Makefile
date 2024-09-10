INCL = -I.
CFLAGS = -Wall -O3 $(INCL)
UNAME = $(shell uname)
CC = gcc
LD = gcc
LDFLAGS = -lX11

RV_OBJS = randvideo.o mem_driver.o io_driver.o
RV_TARGET = randvideo
CONS_OBJS = console.o mem_driver.o io_driver.o
CONS_TARGET = console

all: $(RV_TARGET) $(CONS_TARGET)

$(RV_TARGET): $(RV_OBJS)

	$(LD) $(RV_OBJS) -o $(RV_TARGET) $(LDFLAGS)

$(CONS_TARGET): $(CONS_OBJS)

	$(LD) $(CONS_OBJS) -o $(CONS_TARGET) $(LDFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) -c $<

clean:
	rm -f *.o
	rm -f *~
	rm -f $(RV_TARGET)
	rm -f $(CONS_TARGET)
