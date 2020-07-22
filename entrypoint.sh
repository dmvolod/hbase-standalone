#!/bin/bash

function waitPort {
  port=$1

  while true; do
    echo "Checking TCP status for: ${port}"

    nc -zw3 127.0.0.1 $port

    status=$?

    if [ "$status" == "0" ]; then
      echo "Success"
      break
    fi

    sleep 1
  done
}

function addProperty() {
  local path=$1
  local name=$2
  local value=$3

  local entry="<property><name>$name</name><value>${value}</value></property>"
  local escapedEntry=$(echo $entry | sed 's/\//\\\//g')
  sed -i "/<\/configuration>/ s/.*/${escapedEntry}\n&/" $path
}

function configure() {
    local path=$1
    local module=$2
    local envPrefix=$3

    local var
    local value

    echo "Configuring $module"
    for c in `printenv | perl -sne 'print "$1 " if m/^${envPrefix}_(.+?)=.*/' -- -envPrefix=$envPrefix`; do
        name=`echo ${c} | perl -pe 's/___/-/g; s/__/_/g; s/_/./g'`
        var="${envPrefix}_${c}"
        value=${!var}
        echo " - Setting $name=$value"
        addProperty ${HBASE_CONF_DIR}/$module-site.xml $name "$value"
    done
}

echo "" > ${HBASE_CONF_DIR}/regionservers

configure ${HBASE_CONF_DIR}/hbase-site.xml hbase HBASE_CONF

addProperty ${HBASE_CONF_DIR}/hbase-site.xml hbase.rootdir file://${HBASE_DATA_STORAGE}
addProperty ${HBASE_CONF_DIR}/hbase-site.xml hbase.zookeeper.property.dataDir ${ZK_DATA_STORAGE}
addProperty ${HBASE_CONF_DIR}/hbase-site.xml hbase.regionserver.hostname.disable.master.reversedns true
addProperty ${HBASE_CONF_DIR}/hbase-site.xml hbase.cluster.distributed true
addProperty ${HBASE_CONF_DIR}/hbase-site.xml hbase.master.ipc.address 0.0.0.0
addProperty ${HBASE_CONF_DIR}/hbase-site.xml hbase.regionserver.ipc.address 0.0.0.0
addProperty ${HBASE_CONF_DIR}/hbase-site.xml hbase.regionserver.wal.codec org.apache.hadoop.hbase.regionserver.wal.IndexedWALEditCodec

if [[ "${REGIONSERVER_EXTERNAL_PORT}" ]]; then
  addProperty ${HBASE_CONF_DIR}/hbase-site.xml hbase.regionserver.port ${REGIONSERVER_EXTERNAL_PORT}
fi

if [[ "${MASTER_EXTERNAL_PORT}" ]]; then
  addProperty ${HBASE_CONF_DIR}/hbase-site.xml hbase.master.port ${MASTER_EXTERNAL_PORT}
fi

addProperty ${HBASE_CONF_DIR}/hbase-site.xml phoenix.queryserver.service.name ${REPLICA_NAME}

rm -rf /tmp/*.pid

$HBASE_PREFIX/bin/hbase-daemon.sh --config $HBASE_CONF_DIR start zookeeper &
waitPort 2181

$HBASE_PREFIX/bin/hbase-daemon.sh --config $HBASE_CONF_DIR start master &
waitPort 16010

$HBASE_PREFIX/bin/hbase-daemon.sh --config $HBASE_CONF_DIR start regionserver &
waitPort 16030

exec /opt/phoenix/bin/queryserver.py $@
