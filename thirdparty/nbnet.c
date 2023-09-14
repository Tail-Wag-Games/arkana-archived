#define NBNET_IMPL

void ARK_LogInfo(char* format, ...);
void ARK_LogError(char* format, ...);
void ARK_LogDebug(char* format, ...);
void ARK_LogTrace(char* format, ...);

#define NBN_LogInfo(...) ARK_LogInfo(__VA_ARGS__)

#define NBN_LogError(...) ARK_LogError(__VA_ARGS__)
#define NBN_LogWarning(...) ARK_LogWarning(__VA_ARGS__)
#define NBN_LogDebug(...) ARK_LogDebug(__VA_ARGS__)
#define NBN_LogTrace(...) ARK_LogTrace(__VA_ARGS__)

#include "./nbnet/nbnet.h"