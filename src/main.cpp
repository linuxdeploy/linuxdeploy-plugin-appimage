// system includes
#include <cstring>
#include <iostream>
#include <dirent.h>
#include <libgen.h>
#include <unistd.h>

// library includes
#include <args.hxx>

bool isFile(const std::string& path) {
    return access(path.c_str(), F_OK) == 0;
}

std::string findAppimagetool(const char* const argv0) {
    std::vector<char> argv0Buf(strlen(argv0) + 1);
    strcpy(argv0Buf.data(), argv0);

    auto currentDirPath = std::string(dirname(argv0Buf.data()));

    // search next to current binary
    std::vector<std::string> knownPaths = {
        currentDirPath + "/appimagetool",
        currentDirPath + "/appimagetool.AppImage",
        currentDirPath + "/appimagetool-x86_64.AppImage",
    };

    std::stringstream ss;
    ss << getenv("PATH");

    // also search in PATH
    std::string currentPath;
    while (std::getline(ss, currentPath, ':')) {
        knownPaths.push_back(currentPath + "/appimagetool");
        knownPaths.push_back(currentPath + "/appimagetool.AppImage");
        knownPaths.push_back(currentPath + "/appimagetool-x86_64.AppImage");
    }

    for (const auto& path : knownPaths) {
        if (isFile(path))
            return path;
    }

    throw std::runtime_error("Could not find appimagetool in PATH");
}

int main(const int argc, const char* const* const argv) {
    args::ArgumentParser parser("linuxdeploy-plugin-appimage");

    args::ValueFlag<std::string> appdir(parser, "AppDir", "AppDir to package as AppImage", {"appdir"});
    args::Flag pluginType(parser, "", "Return plugin type and exit", {"plugin-type"});

    try {
        parser.ParseCLI(argc, argv);
    } catch (const args::UsageError&) {
        std::cout << parser;
    } catch (const args::ParseError& e) {
        std::cerr << "Failed to parse arguments: " << e.what() << std::endl << std::endl;
        std::cout << parser;
        return 1;
    }

    if (!appdir) {
        std::cerr << "--appdir parameter required" << std::endl << std::endl;
        std::cout << parser;
        return 1;
    }

    if (pluginType) {
        std::cout << "output" << std::endl;
        return 0;
    }

    auto pathToAppimagetool = findAppimagetool(argv[0]);

    execl(pathToAppimagetool.c_str(), "appimagetool", appdir.Get().c_str(), nullptr);

    auto error = errno;
    std::cerr << "execl() failed: " << strerror(error) << std::endl;
}
