# this script runs the passed lua file in headless mode

# check if the file exists
if [ ! -f "$1" ]; then
    echo "File $1 does not exist"
    exit 1
fi

# run the file in headless mode
nvim --headless "$1"
