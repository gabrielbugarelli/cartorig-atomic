#include "cartorig_core.hpp"

#include <fstream>
#include <iostream>
#include <optional>
#include <string>
#include <vector>

namespace {
const char* typeName(cartorig::LocationType t) {
    switch (t) {
        case cartorig::LocationType::Country: return "country";
        case cartorig::LocationType::State: return "state";
        case cartorig::LocationType::City: return "city";
    }
    return "unknown";
}

std::optional<cartorig::LocationType> filterFrom(const std::string& text) {
    if (text == "country") return cartorig::LocationType::Country;
    if (text == "state") return cartorig::LocationType::State;
    if (text == "city") return cartorig::LocationType::City;
    throw std::invalid_argument("type must be country/state/city");
}

bool has(const cartorig::Catalog& catalog, const std::string& query,
         cartorig::LocationType type, bool needsPolygon = false) {
    for (const auto* f : catalog.search(query, type, 100)) {
        if (cartorig::normalizeSearch(f->name) == cartorig::normalizeSearch(query) &&
            (!needsPolygon || !f->polygons.empty())) return true;
    }
    return false;
}
}

int main(int argc, char** argv) {
    try {
        std::string catalogPath;
        std::string searchText;
        std::string filterText;
        bool smoke = false;
        for (int i=1; i<argc; ++i) {
            const std::string key = argv[i];
            if (key == "--catalog" && i+1<argc) catalogPath = argv[++i];
            else if (key == "--search" && i+1<argc) searchText = argv[++i];
            else if (key == "--type" && i+1<argc) filterText = argv[++i];
            else if (key == "--smoke") smoke = true;
            else throw std::invalid_argument("use --catalog <path> [--search <name> --type country|state|city] [--smoke]");
        }
        if (catalogPath.empty()) throw std::invalid_argument("--catalog required");
        std::ifstream stream(catalogPath, std::ios::binary);
        if (!stream) throw std::runtime_error("cannot open offline catalog: " + catalogPath);
        const auto catalog = cartorig::Catalog::load(stream);
        std::cout << "CartoRig Atomic: " << catalog.size()
                  << " offline geographic features loaded\n";
        if (!searchText.empty()) {
            auto result = catalog.search(searchText,
                filterText.empty() ? std::nullopt : filterFrom(filterText), 50);
            for (const auto* f : result) {
                std::cout << typeName(f->type) << '\t' << f->name
                          << '\t' << f->parent << '\t' << f->country
                          << '\t' << f->id << '\n';
            }
            if (result.empty()) return 3;
        }
        if (smoke) {
            const bool valid =
                has(catalog,"Rio de Janeiro",cartorig::LocationType::State,true) &&
                has(catalog,"Rio de Janeiro",cartorig::LocationType::City) &&
                has(catalog,"São Paulo",cartorig::LocationType::State,true) &&
                has(catalog,"São Paulo",cartorig::LocationType::City) &&
                has(catalog,"Brasilia",cartorig::LocationType::City) &&
                has(catalog,"Macapa",cartorig::LocationType::City) &&
                has(catalog,"Amapa",cartorig::LocationType::State,true);
            if (!valid) {
                std::cerr << "FAIL: required country/state/city source coverage is missing\n";
                return 2;
            }
            std::cout << "PASS: natural-name Rio/SP/Brasília/Macapá/Amapá coverage smoke\n";
        }
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "FAIL: " << e.what() << '\n';
        return 1;
    }
}
