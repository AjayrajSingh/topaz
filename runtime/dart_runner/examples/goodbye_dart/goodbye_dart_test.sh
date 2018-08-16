#!/boot/bin/sh

run goodbye_dart_aot --now
if [ $? -ne 23 ]; then
    echo "goodbye_dart_aot --now failed"
    exit 1
fi

# run goodbye_dart_jit --now
# if [ $? -ne 23 ]; then
#     echo "goodbye_dart_jit --now failed"
#     exit 1
# fi

run goodbye_dart_aot
if [ $? -ne 42 ]; then
    echo "goodbye_dart_aot failed"
    exit 1
fi

# run goodbye_dart_jit
# if [ $? -ne 42 ]; then
#     echo "goodbye_dart_jit failed"
#     exit 1
# fi
