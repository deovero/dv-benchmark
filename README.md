# dv-benchmark
Hardware Benchmarking Tools by [DeoVero](https://deovero.com).

# Usage
```shell
mkdir -p ~/tmp
cd ~/tmp
git clone https://github.com/deovero/dv-benchmark.git
cd dv-benchmark
./iozone.sh
./fio.sh
./sysbench.sh
```

# Quick Test for development
FILE_SIZE=100M RUN_TIME=5 ./fio.sh
FILE_SIZE=100M ./iozone.sh
RUN_TIME=5 ./sysbench.sh
