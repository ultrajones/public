#!/bin/bash
# File: test-all-physical-disks.sh
# Save as ~/test-all-disks.sh, then: chmod +x ~/test-all-disks.sh && sudo ~/test-all-disks.sh

echo "=== Physical disk max-performance benchmark ==="
echo "   (sequential read/write, human-readable output)"
echo

# List of block devices that are real physical disks
DISKS=$(lsblk -d -n -p --output NAME,TRAN,TYPE | grep -E 'sata|sas|nvme|usb|virtio|ide' | grep disk | awk '{print $1}')

if [ -z "$DISKS" ]; then
    echo "No physical disks found!"
    exit 1
fi

for DEV in $DISKS; do
    MODEL=$(cat /sys/block/$(basename $DEV)/device/model 2>/dev/null || echo "Unknown")
    SIZE=$(lsblk -d -n -b -o SIZE $DEV | awk '{printf "%.1f GB", $1/1000000000}')
    
    echo "------------------------------------------------------------"
    echo "Testing: $DEV  |  $MODEL  |  ${SIZE}"
    echo "------------------------------------------------------------"

    # 1. Max sequential READ (direct to raw device)
    echo "→ Max READ speed (direct raw device)..."
    sudo fio --name=read-test \
      --filename=$DEV \
      --rw=read \
      --bs=1M \
      --iodepth=128 \
      --numjobs=4 \
      --runtime=15 \
      --time_based \
      --direct=1 \
      --ioengine=libaio \
      --gtod_reduce=1 \
      --group_reporting \
      --output-format=human 2>/dev/null | grep -E "READ:.*BW="
    
    # 2. Max sequential WRITE (to a file in /tmp – safe, never touches mounted FS)
    echo "→ Max WRITE speed (file in /tmp)..."
    sudo fio --name=write-test \
      --filename=/tmp/fio-test-$DEV.tmp \
      --rw=write \
      --bs=1M \
      --iodepth=128 \
      --numjobs=4 \
      --runtime=15 \
      --time_based \
      --direct=1 \
      --ioengine=libaio \
      --gtod_reduce=1 \
      --group_reporting \
      --output-format=human 2>/dev/null | grep -E "WRITE:.*BW="
    
    # Cleanup write file
    rm -f /tmp/fio-test-$DEV.tmp
    
    echo
done

echo "=== All disks tested ==="
