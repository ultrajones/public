#!/bin/bash

################################################################################
# Disk Speed Test Script
# Automatically detects physical disks and tests read/write performance
# Uses fio (Flexible I/O Tester) for accurate benchmarking
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Warning: Running without root privileges. Some disks may not be accessible.${NC}"
    echo -e "${YELLOW}Consider running with: sudo $0${NC}\n"
fi

# Check if fio is installed
if ! command -v fio &> /dev/null; then
    echo -e "${RED}Error: fio is not installed. Please install it first.${NC}"
    echo "Ubuntu/Debian: sudo apt-get install fio"
    echo "RHEL/CentOS: sudo yum install fio"
    exit 1
fi

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  Disk Speed Test Utility${NC}"
echo -e "${GREEN}================================${NC}\n"

# Function to detect physical disks
detect_disks() {
    echo -e "${BLUE}Detecting physical disks...${NC}\n"
    
    # Get list of block devices (excluding loop, ram, and other virtual devices)
    DISKS=$(lsblk -nd -o NAME,TYPE,SIZE,MODEL | grep "disk" | awk '{print $1}')
    
    if [ -z "$DISKS" ]; then
        echo -e "${RED}No physical disks detected!${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Found the following disks:${NC}"
    echo "----------------------------------------"
    lsblk -d -o NAME,SIZE,MODEL,ROTA,TYPE | grep -E "NAME|disk"
    echo "----------------------------------------"
    echo ""
}

# Function to run fio test
run_fio_test() {
    local disk=$1
    local test_name=$2
    local rw_type=$3
    local block_size=$4
    
    echo -e "${YELLOW}Running $test_name test on /dev/$disk...${NC}"
    
    # Create temporary test file path
    TEST_FILE="/tmp/fio_test_${disk}_${RANDOM}"
    
    # Run fio test
    fio --name="${test_name}" \
        --filename="${TEST_FILE}" \
        --size=1G \
        --rw="${rw_type}" \
        --bs="${block_size}" \
        --ioengine=libaio \
        --direct=1 \
        --numjobs=1 \
        --iodepth=32 \
        --runtime=30 \
        --time_based \
        --group_reporting \
        --output-format=normal 2>/dev/null | grep -E "READ:|WRITE:|read :|write:"
    
    # Clean up
    rm -f "${TEST_FILE}"
    echo ""
}

# Function to run comprehensive disk test
test_disk() {
    local disk=$1
    
    echo -e "\n${GREEN}======================================${NC}"
    echo -e "${GREEN}Testing /dev/$disk${NC}"
    echo -e "${GREEN}======================================${NC}\n"
    
    # Get disk info
    DISK_SIZE=$(lsblk -nd -o SIZE /dev/$disk)
    DISK_MODEL=$(lsblk -nd -o MODEL /dev/$disk)
    DISK_ROTA=$(lsblk -nd -o ROTA /dev/$disk)
    
    if [ "$DISK_ROTA" = "1" ]; then
        DISK_TYPE="HDD (Rotational)"
    else
        DISK_TYPE="SSD (Non-rotational)"
    fi
    
    echo "Disk: /dev/$disk"
    echo "Size: $DISK_SIZE"
    echo "Model: $DISK_MODEL"
    echo "Type: $DISK_TYPE"
    echo ""
    
    # Sequential Read Test
    run_fio_test "$disk" "Sequential-Read" "read" "1M"
    
    # Sequential Write Test
    run_fio_test "$disk" "Sequential-Write" "write" "1M"
    
    # Random Read Test (4K blocks)
    run_fio_test "$disk" "Random-Read-4K" "randread" "4K"
    
    # Random Write Test (4K blocks)
    run_fio_test "$disk" "Random-Write-4K" "randwrite" "4K"
    
    echo -e "${GREEN}Test completed for /dev/$disk${NC}"
}

# Function to create summary report
create_summary() {
    echo -e "\n${GREEN}======================================${NC}"
    echo -e "${GREEN}  Test Summary${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo ""
    echo "All tests completed at: $(date)"
    echo ""
    echo "Test Parameters:"
    echo "  - File size: 1GB"
    echo "  - Runtime per test: 30 seconds"
    echo "  - I/O Engine: libaio (Linux native async I/O)"
    echo "  - Direct I/O: Enabled (bypasses OS cache)"
    echo "  - Queue depth: 32"
    echo ""
    echo "Tests performed per disk:"
    echo "  1. Sequential Read (1MB blocks)"
    echo "  2. Sequential Write (1MB blocks)"
    echo "  3. Random Read (4K blocks)"
    echo "  4. Random Write (4K blocks)"
    echo ""
}

# Main execution
main() {
    detect_disks
    
    # Ask user which disks to test
    echo -e "${YELLOW}Options:${NC}"
    echo "1) Test all detected disks"
    echo "2) Select specific disks to test"
    echo ""
    read -p "Enter your choice (1 or 2): " choice
    
    case $choice in
        1)
            echo -e "\n${GREEN}Testing all disks...${NC}"
            for disk in $DISKS; do
                test_disk "$disk"
            done
            ;;
        2)
            echo -e "\n${YELLOW}Available disks:${NC}"
            select disk in $DISKS "Done"; do
                if [ "$disk" = "Done" ]; then
                    break
                elif [ -n "$disk" ]; then
                    test_disk "$disk"
                    echo -e "\n${YELLOW}Select another disk or choose 'Done':${NC}"
                fi
            done
            ;;
        *)
            echo -e "${RED}Invalid choice!${NC}"
            exit 1
            ;;
    esac
    
    create_summary
    
    echo -e "${GREEN}All tests completed successfully!${NC}"
}

# Run main function
main
