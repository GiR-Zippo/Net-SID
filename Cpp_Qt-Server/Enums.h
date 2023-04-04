
#ifndef ENUMS_H
#define ENUMS_H

enum command_list
{
    FLUSH = 0,
    TRY_SET_SID_COUNT,
    MUTE,
    TRY_RESET,
    TRY_DELAY,
    TRY_WRITE,
    TRY_READ,
    GET_VERSION,
    TRY_SET_SAMPLING,
    TRY_SET_CLOCKING,
    GET_CONFIG_COUNT,
    GET_CONFIG_INFO,
    SET_SID_POSITION,
    SET_SID_LEVEL,
    TRY_SET_SID_MODEL
};

enum response_list
{
    OK = 0,
    BUSY,
    ERR,
    READ,
    VERSION,
    COUNT,
    INFO
};

#endif // ENUMS_H
