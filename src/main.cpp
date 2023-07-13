// system includes
#include <cassert>
#include <cstring>
#include <dirent.h>
#include <functional>
#include <iostream>
#include <libgen.h>
#include <optional>
#include <string>
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

/**
 * Fetch variable from environment by name(s).
 * The first name is treated as the currently accepted one, whereas the others are still supported but will trigger a
 * warning.
 * @param names One or more names
 * @return value if available, std::nullopt otherwise
 */
std::optional<std::string> getEnvVar(std::initializer_list<std::string> names) {
    assert(names.size() >= 1);

    for (auto it = names.begin(); it != names.end(); ++it) {
        const auto* value = getenv(it->c_str());

        if (value == nullptr) {
            continue;
        }

        if (it != names.begin()) {
            std::cerr << "Warning: please use $" << *names.begin() << " instead of $" << *it << std::endl;
        }

        return value;
    }

    return std::nullopt;
}

void doSomethingWithEnvVar(std::initializer_list<std::string> names, const std::function<void(const std::string&)>& todo) {
    const auto value = getEnvVar(names);

    if (value.has_value()) {
        todo(value.value());
    }
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

    doSomethingWithEnvVar({"LDAI_SIGN", "SIGN"}, [&](const auto& value) {
        (void) value;
        args.push_back(strdup("-s"));

        doSomethingWithEnvVar({"LDAI_SIGN_KEY", "SIGN_KEY"}, [&](const auto& signKey) {
            args.push_back(strdup("--sign-key"));
            args.push_back(strdup(signKey.c_str()));
        });

        doSomethingWithEnvVar({"LDAI_SIGN_ARGS", "SIGN_ARGS"}, [&](const auto& signArgs) {
            args.push_back(strdup("--sign-args"));
            args.push_back(strdup(signArgs.c_str()));
        });
    });

    constexpr auto appimagetool_verbose_arg = "-v";

    doSomethingWithEnvVar({"LDAI_VERBOSE", "VERBOSE"}, [&](const auto& value) {
        (void) value;
        args.push_back(strdup(appimagetool_verbose_arg));
    });

    // the only exception to prefixing is $DEBUG, which is used across multiple linuxdeploy plugins
    doSomethingWithEnvVar({"DEBUG"}, [&](const auto& value) {
        (void) value;

        // avoid duplicates
        if (std::find(args.begin(), args.end(), appimagetool_verbose_arg) == args.end()) {
            args.push_back(strdup(appimagetool_verbose_arg));
        }
    });

    doSomethingWithEnvVar({"LDAI_OUTPUT", "OUTPUT"}, [&](const auto& value) {
        (void) value;
        args.push_back(strdup(value.c_str()));
    });

    doSomethingWithEnvVar({"LDAI_NO_APPSTREAM", "NO_APPSTREAM"}, [&](const auto& value) {
        (void) value;
        args.push_back(strdup("--no-appstream"));
    });

    doSomethingWithEnvVar({"LDAI_COMP", "APPIMAGE_COMP"}, [&](const auto& value) {
        args.push_back(strdup("--comp"));
        args.push_back(strdup(value.c_str()));
    });

    // $VERSION is already picked up by appimagetool
    doSomethingWithEnvVar({"LINUXDEPLOY_OUTPUT_APP_NAME"}, [&](const auto& value) {
        setenv("APPIMAGETOOL_APP_NAME", value.c_str(), true);
    });

    // $VERSION is already picked up by appimagetool
    doSomethingWithEnvVar({"LINUXDEPLOY_OUTPUT_VERSION", "LDAI_VERSION", "VERSION"}, [&](const auto& value) {
        setenv("VERSION", value.c_str(), true);
    });

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
