FROM mcr.microsoft.com/dotnet/sdk:5.0 AS build
RUN apt-get update -y
RUN curl -fsSL https://deb.nodesource.com/setup_14.x | bash -
RUN apt-get install -y nodejs
RUN npm install --global yarn
WORKDIR /source
RUN git clone --depth 1 -b master https://github.com/Radarr/Radarr.git
WORKDIR /source/Radarr
RUN sed -i "s/connectionBuilder.JournalMode = .*/connectionBuilder.JournalMode = SQLiteJournalModeEnum.Truncate;/g" ./src/NzbDrone.Core/Datastore/ConnectionStringFactory.cs
RUN ./build.sh --all --framework net5.0 --runtime linux-x64
RUN tar cvzf radarr.tar.gz _artifacts/linux-x64/net5.0/Radarr

FROM ghcr.io/linuxserver/baseimage-ubuntu:focal

# set version label
ARG BUILD_DATE
ARG VERSION
ARG RADARR_RELEASE
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="thelamer"

# environment settings
ARG DEBIAN_FRONTEND="noninteractive"
ARG RADARR_BRANCH="master"
ENV XDG_CONFIG_HOME="/config/xdg"

COPY --from=build /source/Radarr/radarr.tar.gz /tmp/radarr.tar.gz

RUN \
 echo "**** install packages ****" && \
 apt-get update && \
 apt-get install --no-install-recommends -y \
	jq \
	libicu66 \
	libmediainfo0v5 \
	sqlite3 && \
 echo "**** install radarr ****" && \
 mkdir -p /app/radarr/bin && \
 tar ixzf \
	/tmp/radarr.tar.gz -C \
	/app/radarr/bin --strip-components=1 && \
 echo "UpdateMethod=docker\nBranch=${RADARR_BRANCH}\nPackageVersion=${VERSION}\nPackageAuthor=linuxserver.io" > /app/radarr/package_info && \
 echo "**** cleanup ****" && \
 rm -rf \
	/app/radarr/bin/Radarr.Update \
	/tmp/* \
	/var/lib/apt/lists/* \
	/var/tmp/*

# copy local files
COPY root/ /

# ports and volumes
EXPOSE 7878
VOLUME /config
