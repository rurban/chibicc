CFLAGS=-std=c11 -g -fno-common -Wall -Wno-switch

SRCS=$(wildcard *.c)
OBJS=$(SRCS:.c=.o)

TEST_SRCS=$(wildcard test/*.c)
FAIL_TEST_SRCS=$(wildcard test/*.c_fail)
TESTS=$(TEST_SRCS:.c=.exe)
FAIL_TESTS=$(FAIL_TEST_SRCS:.c_fail=.fail)

# Stage 1

chibicc: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

$(OBJS): chibicc.h

test/%.exe: chibicc test/%.c
	./chibicc -Iinclude -Itest -c -o test/$*.o test/$*.c
	$(CC) -pthread -o $@ test/$*.o -xc test/common

test/%.fail: chibicc test/%.c_fail
	echo "cat <<EOF" >test/$*.fail
	./chibicc -Iinclude -Itest -xc -c test/$*.c_fail 2>>test/$*.fail || \
	  (echo OK; printf "EOF\necho OK\n" >>test/$*.fail; chmod +x test/$*.fail)

test: $(TESTS) $(FAIL_TESTS)
	for i in $^; do echo $$i; ./$$i || exit 1; echo; done
	test/driver.sh ./chibicc

test-all: test test-stage2

# Stage 2

stage2/chibicc: $(OBJS:%=stage2/%)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

stage2/%.o: chibicc %.c
	mkdir -p stage2/test
	./chibicc -c -o $(@D)/$*.o $*.c

stage2/test/%.exe: stage2/chibicc test/%.c
	mkdir -p stage2/test
	./stage2/chibicc -Iinclude -Itest -c -o stage2/test/$*.o test/$*.c
	$(CC) -pthread -o $@ stage2/test/$*.o -xc test/common

test-stage2: $(TESTS:test/%=stage2/test/%)
	for i in $^; do echo $$i; ./$$i || exit 1; echo; done
	test/driver.sh ./stage2/chibicc

# Misc.

install:
	test -d /usr/local/include/x86_64-linux-gnu/chibicc || \
		sudo mkdir -p /usr/local/include/x86_64-linux-gnu/chibicc
	sudo cp include/* /usr/local/include/x86_64-linux-gnu/chibicc/
	sudo cp chibicc /usr/local/bin/chibicc

clean:
	rm -rf chibicc tmp* $(TESTS) test/*.s test/*.exe stage2 test/*.fail
	find * -type f '(' -name '*~' -o -name '*.o' ')' -exec rm {} ';'

.PHONY: test clean test-stage2
