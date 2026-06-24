FROM docker.aquaveo.com/cscott/testdockerregistry/tribs-worker:latest

#####################
# Default Variables #
#####################
ENV CONDOR_HOME="/var/lib/condor"
ENV CONDA_ENV_NAME="tethys"
ENV TETHYSAPP_DIR="/var/python/tethys/apps"
ENV MAMBA_EXE="${CONDOR_HOME}/.local/bin/micromamba"
ENV MAMBA_ROOT_PREFIX="${CONDOR_HOME}/micromamba"
ENV MAMBA_RELEASE_URL="https://github.com/mamba-org/micromamba-releases/releases/latest/download/micromamba-linux-64"
ENV TETHYS_ENV_ROOT="${MAMBA_ROOT_PREFIX}/envs/tethys"
ENV PROJ_LIB="${TETHYS_ENV_ROOT}/share/proj/"
ENV _CONDOR_DESIGNATED_PROJECT="TRIBS"

################
# SETUP PYTHON #
################

# Install Micromamba
USER root
RUN apt-get -yqq update \
    && apt-get -yqq install -o=Dpkg::Use-Pty=0 gfortran curl git libpq-dev python3-dev gcc-12 openmpi-bin libgdal-dev g++ libhdf5-dev > /dev/null \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p "${TETHYSAPP_DIR}" \
    && mkdir -p "${MAMBA_ROOT_PREFIX}"

# Setup environment 
RUN mkdir -p ${CONDOR_HOME}/.local/bin \
    && curl ${MAMBA_RELEASE_URL} -o ${MAMBA_EXE} -fsSL --compressed \
    && chmod +x ${MAMBA_EXE}

# Setup Conda Environment
WORKDIR ${TETHYSAPP_DIR}

# Make pip quieter
RUN mkdir -p ${CONDOR_HOME}/.config/pip && echo "[global]\nquiet = True" > ${CONDOR_HOME}/.config/pip/pip.conf

# Add conda-forge as the default channel and create the environment
ADD conda-lock.yml /tmp/conda-lock.yml
RUN ${MAMBA_EXE} create -n "${CONDA_ENV_NAME}" "python<3.11" \
    && ${MAMBA_EXE} install -y -n "${CONDA_ENV_NAME}" -f /tmp/conda-lock.yml \
    && ${MAMBA_EXE} clean -a -y

###########
# INSTALL #
###########
ADD . ${TETHYSAPP_DIR}

# Install tethysext-atcore
RUN cd ${TETHYSAPP_DIR}/tethysext-atcore \
    && ${TETHYS_ENV_ROOT}/bin/pip install .

# Mark git safe directory and ignore changes caused by .dockerignore
RUN git config --global --add safe.directory '*' \
    && git update-index --assume-unchanged ${TETHYSAPP_DIR}/tribs-adapter

# Install trib-adapter
RUN cd ${TETHYSAPP_DIR}/tribs-adapter \
    && ${TETHYS_ENV_ROOT}/bin/pip install --upgrade resolvelib \
    && ${TETHYS_ENV_ROOT}/bin/pdm use -f ${TETHYS_ENV_ROOT}/bin/python \
    && ${TETHYS_ENV_ROOT}/bin/pdm install --prod

# This needs to be here for the following error:
#UnboundLocalError: local variable 'input_raster_file' referenced before assignment
#UnboundLocalError("local variable 'input_raster_file' referenced before assignment")local variable 'input_raster_file' referenced before assignment
RUN ${TETHYS_ENV_ROOT}/bin/pip install 'shapely>=2.0.0'

# Symbolic link to python
# USER root
RUN /bin/bash -c "ln -s ${TETHYS_ENV_ROOT}/bin/python /opt/tethys-python"

# Permissions
RUN /bin/bash -c "echo 'prj = {}' > ${TETHYS_ENV_ROOT}/lib/python3.10/site-packages/epsgref.py && \
    chmod a=wr ${TETHYS_ENV_ROOT}/lib/python3.10/site-packages/epsgref.py"

RUN chmod +x $(/opt/tethys-python -c "from tribs_adapter.tribs import get_tribs_path; print(get_tribs_path())")

# Verify tethys_dataset_services version is greater than 2.4.1
ADD check_versions.py /tmp/check_versions.py
RUN chmod +x /tmp/check_versions.py \
    && /tmp/check_versions.py
