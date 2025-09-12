FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive

# Update image and install tools, dependencies
RUN apt update && apt upgrade --no-install-recommends -y && apt autoremove -y
RUN apt install --no-install-recommends -y python3 python3-pip pipx build-essential ninja-build gdb git wget libssl-dev protobuf-compiler
RUN pipx install gcovr

# Install CMake
ENV CMAKE_VERSION=3.30
ENV CMAKE_BUILD=2
WORKDIR /opt
RUN wget https://cmake.org/files/v$CMAKE_VERSION/cmake-$CMAKE_VERSION.$CMAKE_BUILD.tar.gz
RUN tar -xzvf cmake-$CMAKE_VERSION.$CMAKE_BUILD.tar.gz
WORKDIR /opt/cmake-$CMAKE_VERSION.$CMAKE_BUILD
RUN ./bootstrap
RUN make -j$(nproc)
RUN make install
WORKDIR /opt
RUN rm -rf cmake*
RUN cmake --version

# Install Cppcheck
WORKDIR /opt
RUN git clone https://github.com/danmar/cppcheck.git
RUN mkdir /opt/cppcheck/build
WORKDIR /opt/cppcheck/build
RUN cmake .. -G Ninja
RUN cmake --build . -j$(nproc)
ENV PATH="${PATH}:/opt/cppcheck/build/bin/"

# Install Doxygen
RUN apt install -y flex bison
WORKDIR /opt
RUN git clone https://github.com/doxygen/doxygen.git
RUN mkdir /opt/doxygen/build
WORKDIR /opt/doxygen/build
RUN cmake -G "Unix Makefiles" ..
RUN make -j$(nproc)
RUN make install

# Install Uncrustify
WORKDIR /opt
RUN git clone https://github.com/uncrustify/uncrustify.git
RUN mkdir /opt/uncrustify/build
WORKDIR /opt/uncrustify/build
RUN cmake -G Ninja -DCMAKE_BUILD_TYPE=Release ..
RUN cmake --build . --config Release -j$(nproc)
RUN cmake --build . --target install

# Install Valgrind
FROM uncrustify-build AS valgrind-build
ENV VALGRIND_VERSION=3.25
ENV VALGRIND_BUILD=1
RUN apt install perl
WORKDIR /opt
RUN mkdir valgrind
RUN wget https://sourceware.org/pub/valgrind/valgrind-$VALGRIND_VERSION.$VALGRIND_BUILD.tar.bz2
RUN bzip2 -d valgrind-$VALGRIND_VERSION.$VALGRIND_BUILD.tar.bz2 && tar -xvf valgrind-$VALGRIND_VERSION.$VALGRIND_BUILD.tar
WORKDIR /opt/valgrind-$VALGRIND_VERSION.$VALGRIND_BUILD
RUN ./configure --prefix=/opt/valgrind && make -j$(nproc) && make install
WORKDIR /opt
RUN rm -rf valgrind-$VALGRIND_VERSION.$VALGRIND_BUILD*
ENV PATH="${PATH}:/opt/valgrind/bin"
RUN valgrind --version

# Cleanup
WORKDIR /root
RUN apt clean
RUN rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/*