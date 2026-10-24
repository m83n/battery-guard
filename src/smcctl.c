// Minimal SMC key reader/writer.
// Usage: smcctl KEY            -> prints value bytes in hex
//        smcctl KEY HEXBYTES   -> writes bytes (root required)
#include <IOKit/IOKitLib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

typedef struct { char major, minor, build, reserved; UInt16 release; } Vers;
typedef struct { UInt16 version, length; UInt32 cpu, gpu, mem; } PLimit;
typedef struct { UInt32 dataSize, dataType; char dataAttributes; } KeyInfo;
typedef struct {
    UInt32 key; Vers vers; PLimit pLimit; KeyInfo keyInfo;
    char result, status, data8; UInt32 data32; unsigned char bytes[32];
} SMCData;

enum { KERNEL_INDEX = 2, CMD_READ = 5, CMD_WRITE = 6, CMD_INFO = 9 };

static io_connect_t conn;

static int call(SMCData *in, SMCData *out) {
    size_t sz = sizeof(SMCData);
    kern_return_t r = IOConnectCallStructMethod(conn, KERNEL_INDEX, in, sizeof(SMCData), out, &sz);
    return (r == kIOReturnSuccess && out->result == 0) ? 0 : -1;
}

int main(int argc, char **argv) {
    if (argc < 2 || strlen(argv[1]) != 4) { fprintf(stderr, "usage: smcctl KEY [HEX]\n"); return 2; }
    io_service_t svc = IOServiceGetMatchingService(MACH_PORT_NULL, IOServiceMatching("AppleSMC"));
    if (!svc || IOServiceOpen(svc, mach_task_self(), 0, &conn) != kIOReturnSuccess) { fprintf(stderr, "cannot open AppleSMC\n"); return 1; }

    SMCData in = {0}, out = {0};
    const char *k = argv[1];
    in.key = ((UInt32)k[0] << 24) | ((UInt32)k[1] << 16) | ((UInt32)k[2] << 8) | (UInt32)k[3];
    in.data8 = CMD_INFO;
    if (call(&in, &out)) { fprintf(stderr, "key %s not found\n", k); return 1; }
    UInt32 size = out.keyInfo.dataSize;
    if (size == 0 || size > sizeof(in.bytes)) { fprintf(stderr, "unsupported key size %u\n", size); return 1; }

    if (argc == 2) {
        in.keyInfo.dataSize = size;
        in.data8 = CMD_READ;
        memset(&out, 0, sizeof out);
        if (call(&in, &out)) { fprintf(stderr, "read failed\n"); return 1; }
        for (UInt32 i = 0; i < size; i++) printf("%02x", out.bytes[i]);
        printf("\n");
        return 0;
    }

    const char *hex = argv[2];
    if (strlen(hex) != size * 2) { fprintf(stderr, "need %u bytes\n", size); return 2; }
    for (UInt32 i = 0; i < size * 2; i++) if (!isxdigit((unsigned char)hex[i])) { fprintf(stderr, "bad hex\n"); return 2; }
    for (UInt32 i = 0; i < size; i++) { char b[3] = {hex[2*i], hex[2*i+1], 0}; in.bytes[i] = (unsigned char)strtoul(b, NULL, 16); }
    in.keyInfo.dataSize = size;
    in.data8 = CMD_WRITE;
    if (call(&in, &out)) { fprintf(stderr, "write failed (root?)\n"); return 1; }
    return 0;
}
