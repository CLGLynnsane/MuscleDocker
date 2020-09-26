# use ubuntu as the image OS because everyone does, I guess
FROM ubuntu:16.04

# we need wget to install miniconda
RUN apt-get update && \
    apt-get install -y wget && \
    rm -rf /var/lib/apt/lists/*

# make sure bash is the default shell
# --login makes sure both .profile and .bashrc are
# sourced.
SHELL ["/bin/bash", "--login", "-c"]

# create a non-root user to run everything, for safety
ARG username=docker_user
ARG uid=1000
ARG gid=100
ENV USER $username
ENV UID $uid
ENV GID $gid
ENV HOME /home/$USER

RUN adduser --disabled-password \
    --gecos "Non-root user" \
    --uid $UID \
    --gid $GID \
    --home $HOME \
    $USER

# copy over set up files

# the conda env
COPY environment.yml /tmp/
RUN chown $UID:$GID /tmp/environment.yml

# post conda env setup
COPY postBuild.sh /usr/local/bin/
RUN chown $UID:$GID /usr/local/bin/postBuild.sh && \
    chmod a+x /usr/local/bin/postBuild.sh

# 
COPY entryPoint.sh /usr/local/bin/
RUN chown $UID:$GID /usr/local/bin/entryPoint.sh && \
    chmod a+x /usr/local/bin/entryPoint.sh

# start running things (as docker_user)
USER $USER

# install miniconda
ENV MINICONDA_VERSION 4.8.5
ENV CONDA_DIR $HOME/miniconda3
#RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-$MINICONDA_VERSION-Linux-x86_64.sh -O ~/miniconda.sh && \
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && \
    chmod +x ~/miniconda.sh && \
    ~/miniconda.sh -b -p $CONDA_DIR && \
    rm ~/miniconda.sh

# put conda stuff in PATH
ENV PATH=$CONDA_DIR/bin:$PATH

# make conda.sh available when logging in to shell (/bin/bash --login)
RUN echo ". $CONDA_DIR/etc/profile.d/conda.sh" >> ~/.profile

# make conda available from interactive shell (/bin/bash --interactive)
RUN conda init bash

# create project dir in home and go to it
ENV PROJECT_DIR $HOME/project
RUN mkdir $PROJECT_DIR
WORKDIR $PROJECT_DIR

# build conda environment
ENV ENV_PREFIX $PROJECT_DIR/env
RUN conda update --name base --channel defaults conda && \
    conda env create --prefix $ENV_PREFIX --file /tmp/environment.yml --force && \
    conda clean --all --yes

# activate environment and run post build script
RUN conda activate $ENV_PREFIX && \
    /usr/local/bin/postBuild.sh && \
    conda deactivate

# ensure cnda env is activated at runtime
#ENTRYPOINT ["/usr/local/bin/entryPoint.sh"]

# execute our job in the form of a bash script
# Actually, I think with RIS/Compute docker scripts, the usual job script is passed
#CMD ["sh", "job.sh"]
