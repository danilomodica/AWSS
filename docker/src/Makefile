CC = gcc
CFLAGS  = -Wall -O2 -fopenmp
TARGET = lcs

all:$(TARGET)

$(TARGET):lcs_algorithm.c
	$(CC) $(CFLAGS) -o $(TARGET) lcs_algorithm.c
	
clean:
	$(RM) $(TARGET)
