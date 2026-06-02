FROM ubuntu:latest AS base

ENV DEBIAN_FRONTEND=noninteractive

# Update image and install tools, dependencies
RUN apt-get update \
    && apt-get upgrade --no-install-recommends -y  \
    && apt-get install --no-install-recommends -y \
    # General
    git wget curl unzip gpg dirmngr \
    python3 python3-pip pipx \
    build-essential ninja-build gdb \
    libssl-dev protobuf-compiler \
    # Cppcheck
    python3-pygments \
    # Doxygen
    flex bison \
    # valgrind
    perl \
    bzip2 \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
RUN pipx install gcovr

#Install CMake
FROM base AS cmake-build
ENV CMAKE_VERSION=4.3 CMAKE_BUILD=3
WORKDIR /opt
RUN wget -q https://cmake.org/files/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.${CMAKE_BUILD}.tar.gz \
    && tar -xzf cmake-${CMAKE_VERSION}.${CMAKE_BUILD}.tar.gz \
    && cd cmake-${CMAKE_VERSION}.${CMAKE_BUILD} \
    && ./bootstrap && make -j$(nproc) && make install -j$(nproc) \
    && cd /opt && rm -rf cmake*
RUN cmake --version

# Install Cppcheck
FROM base AS cppcheck-build
COPY --from=cmake-build /usr/local /usr/local
WORKDIR /opt
RUN git clone --depth=1 https://github.com/danmar/cppcheck.git \
    && cmake -S cppcheck -B cppcheck/build -G Ninja -DUSE_MATCHCOMPILER=ON -DCMAKE_BUILD_TYPE=Release \
    && cmake --build cppcheck/build \
    && cmake --build cppcheck/build -t install \
    && rm -rf cppcheck
RUN cppcheck --version

# Install Doxygen
FROM base AS doxygen-build
COPY --from=cmake-build /usr/local /usr/local
WORKDIR /opt
RUN git clone --depth=1 https://github.com/doxygen/doxygen.git \
    && cmake -S doxygen -B doxygen/build -G Ninja \
    && cmake --build doxygen/build \
    && cmake --build doxygen/build -t install \
    && rm -rf doxygen
RUN doxygen --version

# Install Uncrustify
FROM base AS uncrustify-build
COPY --from=cmake-build /usr/local /usr/local
WORKDIR /opt
RUN git clone --depth=1 https://github.com/uncrustify/uncrustify.git \
    && cmake -S uncrustify -B uncrustify/build -G Ninja -DCMAKE_BUILD_TYPE=Release \
    && cmake --build uncrustify/build --config Release \
    && cmake --build uncrustify/build --target install \
    && rm -rf uncrustify
RUN uncrustify --version

# Install Valgrind
FROM base AS valgrind-build
ENV VALGRIND_VERSION=3.26 VALGRIND_BUILD=0
WORKDIR /opt
RUN wget -q https://sourceware.org/pub/valgrind/valgrind-${VALGRIND_VERSION}.${VALGRIND_BUILD}.tar.bz2 \
    && tar -xjf valgrind-${VALGRIND_VERSION}.${VALGRIND_BUILD}.tar.bz2 \
    && cd valgrind-${VALGRIND_VERSION}.${VALGRIND_BUILD} \
    && ./configure --prefix=/opt/valgrind \
    && make -j$(nproc) && make install -j$(nproc) \
    && cd /opt && rm -rf valgrind-${VALGRIND_VERSION}.${VALGRIND_BUILD}*
ENV PATH="${PATH}:/opt/valgrind/bin"
RUN valgrind --version

# Copy to final image
FROM base AS final
COPY --from=cmake-build      /usr/local        /usr/local
COPY --from=cppcheck-build   /usr/local        /usr/local
COPY --from=doxygen-build    /usr/local        /usr/local
COPY --from=uncrustify-build /usr/local        /usr/local
COPY --from=valgrind-build   /opt/valgrind     /opt/valgrind

ENV PATH="${PATH}:/opt/valgrind/bin"
WORKDIR /root