// system includes
#include <cstring>
#include <iostream>
#include <dirent.h>
#include <libgen.h>
#include <unistd.h>
#include <vector>

// library includes
#include <args.hxx>

bool isFile(const std::string& path) {
    return access(path.c_str(), F_OK) == 0;
}

std::string findAppimagetool() {
    std::vector<char> buf(PATH_MAX, '\0');

    if (readlink("/proc/self/exe", buf.data(), buf.size()) < 0) {
        return "";
    }

    auto currentDirPath = std::string(dirname(buf.data()));

    // search next to current binary
    std::vector<std::string> knownPaths = {
        currentDirPath + "/appimagetool",
        currentDirPath + "/appimagetool.AppImage",
        currentDirPath + "/appimagetool-x86_64.AppImage",
        currentDirPath + "/appimagetool-i686.AppImage",
    };

    std::stringstream ss;
    ss << getenv("PATH");

    // also search in PATH
    std::string currentPath;
    while (std::getline(ss, currentPath, ':')) {
        knownPaths.push_back(currentPath + "/appimagetool");
        knownPaths.push_back(currentPath + "/appimagetool.AppImage");
        knownPaths.push_back(currentPath + "/appimagetool-x86_64.AppImage");
        knownPaths.push_back(currentPath + "/appimagetool-i686.AppImage");
    }

    for (const auto& path : knownPaths) {
        if (isFile(path))
            return path;
    }

    return "";
}

int main(const int argc, const char* const* const argv) {
    args::ArgumentParser parser("linuxdeploy-plugin-appimage");

    args::ValueFlag<std::string> appdir(parser, "AppDir", "AppDir to package as AppImage", {"appdir"});
    args::Flag pluginType(parser, "", "Return plugin type and exit", {"plugin-type"});
    args::Flag pluginApiVersion(parser, "", "Return plugin type and exit", {"plugin-api-version"});

    try {
        parser.ParseCLI(argc, argv);
    } catch (const args::UsageError&) {
        std::cout << parser;
    } catch (const args::ParseError& e) {
        std::cerr << "Failed to parse arguments: " << e.what() << std::endl << std::endl;
        std::cout << parser;
        return 1;
    }

    if (pluginApiVersion) {
        std::cout << "0" << std::endl;
        return 0;
    }

    if (pluginType) {
        std::cout << "output" << std::endl;
        return 0;
    }

    if (!appdir) {
        std::cerr << "--appdir parameter required" << std::endl << std::endl;
        std::cout << parser;
        return 1;
    }

    auto pathToAppimagetool = findAppimagetool();

    if (pathToAppimagetool.empty()) {
        std::cerr << "Could not find appimagetool in PATH" << std::endl;
        return 1;
    }

    std::cout << "Found appimagetool: " << pathToAppimagetool << std::endl;

    std::vector<char*> args;
    args.push_back(strdup("appimagetool"));
    args.push_back(strdup(appdir.Get().c_str()));

    auto updateInformation = getenv("UPDATE_INFORMATION");

    // also provide shorter version of the environment variable
    if (updateInformation == nullptr) {
        updateInformation = getenv("UPD_INFO");
    }

    if (updateInformation != nullptr) {
        std::cout << "Embedding update information: " << updateInformation << std::endl;
        args.push_back(strdup("-u"));
        args.push_back(updateInformation);
    } else {
        args.push_back(strdup("-g"));
    }

    if (getenv("SIGN") != nullptr) {
        args.push_back(strdup("-s"));

        const char* signingKey;
        if ((signingKey = getenv("SIGN_KEY")) != nullptr) {
            args.push_back(strdup("--sign-key"));
            args.push_back(strdup(signingKey));
        }

        const char* signingArgs = getenv("SIGN_ARGS");
        if (signingArgs != nullptr) {
            args.push_back(strdup("--sign-args"));
            args.push_back(strdup(signingArgs));
        }
    }

    if (getenv("VERBOSE") != nullptr) {
        args.push_back(strdup("-v"));
    }

    if (getenv("OUTPUT") != nullptr) {
        args.push_back(strdup(getenv("OUTPUT")));
    }

    if (getenv("NO_APPSTREAM") != nullptr) {
        args.push_back(strdup("--no-appstream"));
    }

    args.push_back(nullptr);

    std::cerr << "Running command: " << pathToAppimagetool;
    for (auto it = args.begin() + 1; it != args.end() - 1; it++) {
        std::cerr << " " << "\"" << *it << "\"";
    }
    std::cerr << std::endl << std::endl;

    // separate appimagetool output from plugin's output
    std::cout << std::endl;

    execv(pathToAppimagetool.c_str(), args.data());

    auto error = errno;
    std::cerr << "execl() failed: " << strerror(error) << std::endl;
}
