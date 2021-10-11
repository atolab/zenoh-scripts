#!/bin/bash

get_nodes() # <graph>
{
  cat $1 | grep "\-\-" | sed "s% *\([^ ]*\) *-- *\([^ ;]*\).*%\1|\2%g" | tr '|' '\n' | sort -u
}

node_cmd() # <graph> <node>
{
  local graph=$1
  local node=$2
  local exe=${node%__*}
  local args=${node#*__}
  local port=${args%%_*}
  local httpport=$(($port - 1000))
  local peers=""
  for peer in `cat $graph | grep -e "$node *\-\-" | sed "s% *\([^ ]*\) *-- *\([^ ;]*\).*%\2%g"`
  do 
    local peer_args=${peer#*__}
    local peer_port=${peer_args%%_*}
    if [[ $peers == "" ]] 
    then 
      peers="-e tcp/127.0.0.1:$peer_port"
    else
      peers="$peers -e tcp/127.0.0.1:$peer_port"
    fi
  done
  if [[ "$exe" == "zenohd" ]]
  then
    echo "$exe -c config --rest-http-port $httpport -l tcp/0.0.0.0:$port $peers"
  elif [[ "$exe" == "z_sub" ]] || [[ "$exe" == "z_queryable" ]] || [[ "$exe" == "z_storage" ]] || [[ "$exe" == "z_eval" ]]
  then
    echo "$exe -c config -l tcp/0.0.0.0:$port $peers -s /test/$port"
  else
    echo "$exe -c config -l tcp/0.0.0.0:$port $peers"
  fi
}

run_node() # <graph> <node> [outputdir] [loglevel]
{
  local graph=$1
  local node=$2
  local outputdir=${3:-run_$(basename $graph)_$(date +"%y-%m-%d_%H-%M-%S")}
  local loglevel=${4:-info}
  echo "run_node $graph $node $outputdir $loglevel ..."

  mkdir -p $outputdir
  local cmd=$(node_cmd $graph $node)
  echo "RUST_BACKTRACE=1 RUST_LOG=$loglevel $cmd < /dev/null > $outputdir/$node.log 2>&1"
  eval "RUST_BACKTRACE=1 RUST_LOG=$loglevel $cmd < /dev/null > $outputdir/$node.log 2>&1 &"
}

run_nodes() # <graph> [outputdir] [loglevel] [delay] 
{
  local graph=$1
  local outputdir=${2:-run_$(basename $graph)_$(date +"%y-%m-%d_%H-%M-%S")}
  local loglevel=${3}
  local delay=${4:-0}
  echo "run_nodes $graph $outputdir $loglevel $delay ..."

  mkdir -p $outputdir
  
  for i in `get_nodes $graph`
  do
    run_node $graph $i $outputdir $loglevel
    sleep $delay
  done
}

get_router_pid() # <node>
{
  ps aux | grep zenohd | grep tcp/0.0.0.0:$1 | tr -s ' ' | cut -d' ' -f2
}

kill_router() # <node>
{
  kill $(get_router_pid $1)
}

gen_png() # <graph> [outputfile]
{
  local graph=$1
  local outputfile=${2:-${graph}.png}
  neato -Tpng $graph -o $outputfile
}