FROM invent-registry.kde.org/sysadmin/ci-images/krita-appimage-builder AS base_image

ARG APPIMAGE_UID=1000
ARG APPIMAGE_GID=1000

USER root

#RUN echo 'root:root' | chpasswd

RUN apt-get update
RUN apt-get -y install curl \
                       cmake-curses-gui gdb valgrind sysvinit-utils  \
                       emacs-nox \
                       nano \
                       vim \
                       nomacs \
                       mesa-utils \
                       time \
                       mc \
                       htop \
                       python3.8-venv \
                       cpu-checker # for kvm-ok command

RUN update-alternatives --set gcc /usr/bin/gcc-11
RUN update-alternatives --set g++ /usr/bin/g++-11

ENV USRHOME=/home/appimage
ENV KRITA_WS_PATH=${USRHOME}/build/appimage-workspace
ENV KRITA_SRC_PATH=${USRHOME}/build/src/krita
ENV KRITA_APPIMG_PATH=${USRHOME}/build/appimages

RUN chsh -s /bin/bash appimage

RUN groupmod -g ${APPIMAGE_GID} appimage
RUN usermod -u ${APPIMAGE_UID} -g ${APPIMAGE_GID} appimage

RUN locale-gen en_US.UTF-8

RUN echo 'export LC_ALL=en_US.UTF-8' >> $USRHOME/.bashrc
RUN echo 'export LANG=en_US.UTF-8'  >> $USRHOME/.bashrc
RUN echo "export PS1='\u@\h:\w>'"  >> $USRHOME/.bashrc
RUN echo 'source ~/.bash_devenv' >> $USRHOME/.bashrc
RUN echo 'prepend PATH ~/bin/' >> $USRHOME/.bashrc

RUN mkdir -p $KRITA_WS_PATH/krita.appdir/usr && \
    mkdir -p $KRITA_WS_PATH/krita-build && \
    mkdir -p $KRITA_WS_PATH/deps && \
    mkdir -p $KRITA_WS_PATH/deps-build && \
    mkdir -p $KRITA_APPIMG_PATH && \
    mkdir -p $USRHOME/build/src/downloads && \
    mkdir -p $USRHOME/.config && \
    mkdir -p $USRHOME/.config/gdb && \
    mkdir -p $USRHOME/bin && \
    mkdir -p $USRHOME/data

COPY ./home/.bash_devenv \
     ./home/.bash_aliases \
     $USRHOME/

COPY ./bin/krita-cmd.sh \
     ./bin/run_cmake.sh \
     $USRHOME/bin/

COPY ./home/debug-short.gdb \
     ./home/debug-interactive.gdb \
     $USRHOME/.config/gdb/

RUN chown -R appimage:appimage $USRHOME
RUN chmod a+rwx /tmp
RUN chmod -R a+rx $USRHOME/bin

FROM base_image

USER appimage

CMD tail -f /dev/null
