FROM jboss/base-jdk:8


ENV PHOENIX_SHORT_VERSION 5.0.0-HBase-2.0
ENV PHOENIX_VERSION apache-phoenix-$PHOENIX_SHORT_VERSION
ENV PHOENIX_URL https://www.apache.org/dist/phoenix/$PHOENIX_VERSION/bin/$PHOENIX_VERSION-bin.tar.gz

ENV HBASE_VERSION 2.0.0
ENV HBASE_URL https://archive.apache.org/dist/hbase/$HBASE_VERSION/hbase-$HBASE_VERSION-bin.tar.gz

ENV OPT_HOME /opt

ENV HBASE_SERVER_HOME $OPT_HOME/hbase
ENV HBASE_SERVER_LIB $HBASE_SERVER_HOME/lib
ENV HBASE_SERVER_NATIVE $HBASE_SERVER_LIB/native
ENV PHOENIX_SERVER_HOME $OPT_HOME/phoenix

ENV HBASE_DATA_STORAGE /opt/data/hbase
ENV ZK_DATA_STORAGE /opt/data/zookeeper

# Labels
LABEL name="HBase Standalone Server" \
      version="$HBASE_VERSION" \
      release="$HBASE_VERSION" \
      architecture="x86_64" \
      io.k8s.description="Column-oriented non-relational database management system that runs on top of Hadoop Distributed File System (HDFS)." \
      io.k8s.display-name="HBase Server" \
      io.openshift.expose-services="2181:zookeeper,16000:master-api,16010:master-web,16020:region-api,16030:region-web" \
      io.openshift.tags="bigdata,java,nosql" \
      io.openshift.non-scalable="true"

USER root

RUN yum update -y && yum install -y net-tools nmap-ncat snappy-devel openssl-devel python-devel python3-devel && yum clean all && rm -rf /var/cache/yum

RUN curl -fSL "$HBASE_URL" -o /tmp/hbase.tar.gz && \
    tar -xvf /tmp/hbase.tar.gz -C $OPT_HOME/ && \
    mv $HBASE_SERVER_HOME-$HBASE_VERSION $HBASE_SERVER_HOME && \
    rm -Rf $HBASE_SERVER_HOME/docs && \
    mkdir -p $HBASE_SERVER_NATIVE

RUN curl -fSL "$PHOENIX_URL" -o /tmp/phoenix.tar.gz && \
    tar -xvf /tmp/phoenix.tar.gz -C /tmp/ && \
    mkdir $PHOENIX_SERVER_HOME && \
    cp -r /tmp/$PHOENIX_VERSION-bin/*.jar $PHOENIX_SERVER_HOME && \
    cp -r /tmp/$PHOENIX_VERSION-bin/bin $PHOENIX_SERVER_HOME && \
    cp -r /tmp/$PHOENIX_VERSION-bin/python $PHOENIX_SERVER_HOME && \
    cp /tmp/$PHOENIX_VERSION-bin/phoenix-${PHOENIX_SHORT_VERSION}-server.jar $HBASE_SERVER_LIB && \
    rm -Rf $PHOENIX_SERVER_HOME/*-sources.jar && \
    rm -Rf $PHOENIX_SERVER_HOME/*-tests.jar && \
    chown -R 1000.0 $HBASE_SERVER_HOME $PHOENIX_SERVER_HOME && \
    chmod -R g+rw $HBASE_SERVER_HOME $PHOENIX_SERVER_HOME

RUN rm -Rf /tmp/*

# Prepare data volumes
RUN mkdir -p $HBASE_DATA_STORAGE && chown -R 1000.0 $HBASE_DATA_STORAGE
RUN mkdir -p $ZK_DATA_STORAGE && chown -R 1000.0 $ZK_DATA_STORAGE

VOLUME $HBASE_DATA_STORAGE
VOLUME $ZK_DATA_STORAGE

# zookeeper
EXPOSE 2181
# HBase Master API port
EXPOSE 16000
# HBase Master Web UI
EXPOSE 16010
# Regionserver API port
EXPOSE 16020
# HBase Regionserver web UI
EXPOSE 16030

ENV HBASE_PREFIX=$HBASE_SERVER_HOME
ENV HBASE_CONF_DIR=$HBASE_PREFIX/conf
ENV USER=1000
ENV PATH $HBASE_PREFIX/bin/:$PATH
ENV HBASE_ROOT_LOGGER=INFO,console
ENV HBASE_LOGOUT=/dev/stdout

COPY *.sh /
RUN chmod +x /*.sh

USER 1000

ENTRYPOINT ["/entrypoint.sh"]