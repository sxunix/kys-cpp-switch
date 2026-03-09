#include "Application.h"
#include "Engine.h"
#include "GameUtil.h"

#ifdef __SWITCH__
#include <switch.h>
#endif

int main(int argc, char* argv[])
{
#ifdef __SWITCH__
    socketInitializeDefault();
    nxlinkStdio();
#endif
#ifdef _WIN32
    system("chcp 65001");
#endif
    if (argc >= 2)
    {
        GameUtil::PATH() = argv[1];
    }
    fmt1::print("Game path is {}\n", GameUtil::PATH());
    Application app;
    int ret = app.run();
#ifdef __SWITCH__
    socketExit();
#endif
    return ret;
}
