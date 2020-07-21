FROM jboss/base-jdk:11

ENV HBASE_SERVER_HOME /opt/apache/hbase-server

ENV HBASE_VERSION 2.2.5

ENV HBASE_DATA_STORAGE /opt/hbase/server/data

ENV HOME /opt/apache/

ENV DISTRIBUTION_URL http://mirror.linux-ia64.org/apache/hbase/$HBASE_VERSION/hbase-$HBASE_VERSION-bin.tar.gz

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

RUN curl -o /tmp/server.tar.gz $DISTRIBUTION_URL && mkdir -p $HOME && tar xvf /tmp/server.tar.gz -C $HOME && mv $HOME/hbase-* $HBASE_SERVER_HOME && rm /tmp/server.tar.gz \
    && chown -R 1000.0 $HBASE_SERVER_HOME \
    && chmod -R g+rw $HBASE_SERVER_HOME \
    && find $HBASE_SERVER_HOME -type d -exec chmod g+x {} +

ADD ./conf/ $HBASE_SERVER_HOME/conf/

# Prepare data volume
RUN mkdir -p $HBASE_DATA_STORAGE && chown -R 1000.0 $HBASE_DATA_STORAGE
VOLUME $HBASE_DATA_STORAGE

USER 1000

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

WORKDIR $HBASE_SERVER_HOME
CMD $HBASE_SERVER_HOME/bin/hbase master start