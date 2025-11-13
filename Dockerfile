FROM rocker/rstudio:4.3.1

# Install common system dependencies for R packages (curl, xml2, zlib, fonts, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gfortran \
    pkg-config \
    libxml2-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libgit2-dev \
    zlib1g-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libpng-dev \
    libjpeg-dev \
    libtiff5-dev \
    libicu-dev \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# Copy a small installer script to pre-install R packages used by this project
COPY install_packages.R /tmp/install_packages.R
RUN Rscript /tmp/install_packages.R || true

# Create a project directory and set it as the working directory
RUN mkdir -p /home/rstudio/project
WORKDIR /home/rstudio/project

# The base image runs RStudio Server and exposes 8787 by default. Keep the default init command.
CMD ["/init"]
