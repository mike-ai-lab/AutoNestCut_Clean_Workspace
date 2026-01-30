#include "nesting.h"
#include <iostream>
#include <fstream>
#include <sstream>
#include <chrono>
#include <map>
#include <algorithm>
#include <cctype>

// Minimal JSON parser/writer (no external dependencies)
namespace SimpleJSON {
    
std::string escape_string(const std::string& str) {
    std::string result;
    for (char c : str) {
        switch (c) {
            case '"': result += "\\\""; break;
            case '\\': result += "\\\\"; break;
            case '\n': result += "\\n"; break;
            case '\r': result += "\\r"; break;
            case '\t': result += "\\t"; break;
            default: result += c;
        }
    }
    return result;
}

// Simple JSON value parser
class Value {
public:
    enum Type { NULL_TYPE, BOOL, NUMBER, STRING, ARRAY, OBJECT };
    
    Type type = NULL_TYPE;
    bool bool_val = false;
    double num_val = 0;
    std::string str_val;
    std::vector<Value> array_val;
    std::map<std::string, Value> object_val;
    
    bool is_null() const { return type == NULL_TYPE; }
    bool is_bool() const { return type == BOOL; }
    bool is_number() const { return type == NUMBER; }
    bool is_string() const { return type == STRING; }
    bool is_array() const { return type == ARRAY; }
    bool is_object() const { return type == OBJECT; }
    
    bool as_bool() const { return bool_val; }
    double as_number() const { return num_val; }
    std::string as_string() const { return str_val; }
    
    const Value& operator[](const std::string& key) const {
        static Value null_value;
        auto it = object_val.find(key);
        return it != object_val.end() ? it->second : null_value;
    }
    
    const Value& operator[](size_t index) const {
        static Value null_value;
        return index < array_val.size() ? array_val[index] : null_value;
    }
    
    size_t size() const {
        return is_array() ? array_val.size() : 
               is_object() ? object_val.size() : 0;
    }
};

// Simple recursive descent parser
class Parser {
    std::string json;
    size_t pos = 0;
    
    void skip_whitespace() {
        while (pos < json.size() && std::isspace(json[pos])) pos++;
    }
    
    char peek() {
        skip_whitespace();
        return pos < json.size() ? json[pos] : '\0';
    }
    
    char consume() {
        skip_whitespace();
        return pos < json.size() ? json[pos++] : '\0';
    }
    
    bool match(char c) {
        if (peek() == c) {
            consume();
            return true;
        }
        return false;
    }
    
    std::string parse_string() {
        if (consume() != '"') return "";
        std::string result;
        while (pos < json.size() && json[pos] != '"') {
            if (json[pos] == '\\' && pos + 1 < json.size()) {
                pos++;
                switch (json[pos]) {
                    case 'n': result += '\n'; break;
                    case 'r': result += '\r'; break;
                    case 't': result += '\t'; break;
                    default: result += json[pos];
                }
            } else {
                result += json[pos];
            }
            pos++;
        }
        if (pos < json.size()) pos++; // Skip closing "
        return result;
    }
    
    double parse_number() {
        size_t start = pos;
        if (json[pos] == '-') pos++;
        while (pos < json.size() && (std::isdigit(json[pos]) || json[pos] == '.')) pos++;
        return std::stod(json.substr(start, pos - start));
    }
    
    Value parse_value() {
        Value val;
        char c = peek();
        
        if (c == '"') {
            val.type = Value::STRING;
            val.str_val = parse_string();
        } else if (c == '{') {
            val.type = Value::OBJECT;
            consume(); // {
            while (peek() != '}') {
                std::string key = parse_string();
                if (!match(':')) break;
                val.object_val[key] = parse_value();
                if (!match(',')) break;
            }
            match('}');
        } else if (c == '[') {
            val.type = Value::ARRAY;
            consume(); // [
            while (peek() != ']') {
                val.array_val.push_back(parse_value());
                if (!match(',')) break;
            }
            match(']');
        } else if (c == 't' || c == 'f') {
            val.type = Value::BOOL;
            val.bool_val = (c == 't');
            pos += (c == 't' ? 4 : 5); // Skip "true" or "false"
        } else if (c == 'n') {
            val.type = Value::NULL_TYPE;
            pos += 4; // Skip "null"
        } else if (c == '-' || std::isdigit(c)) {
            val.type = Value::NUMBER;
            val.num_val = parse_number();
        }
        
        return val;
    }
    
public:
    Value parse(const std::string& json_str) {
        json = json_str;
        pos = 0;
        return parse_value();
    }
};

} // namespace SimpleJSON

using namespace AutoNestCut;

// Parse grain direction to allowed rotations
std::vector<int> parse_grain_direction(const std::string& grain) {
    std::string lower = grain;
    std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);
    
    if (lower == "fixed" || lower == "vertical" || lower == "horizontal") {
        return {0}; // No rotation
    }
    return {0, 90}; // Allow 90-degree rotation for "any"
}

int main(int argc, char* argv[]) {
    if (argc != 3) {
        std::cerr << "Usage: nester <input.json> <output.json>" << std::endl;
        return 1;
    }
    
    std::string input_file = argv[1];
    std::string output_file = argv[2];
    
    auto start_time = std::chrono::high_resolution_clock::now();
    
    // Read input JSON
    std::ifstream input(input_file);
    if (!input.is_open()) {
        std::cerr << "ERROR: Cannot open input file: " << input_file << std::endl;
        return 1;
    }
    
    std::stringstream buffer;
    buffer << input.rdbuf();
    std::string json_str = buffer.str();
    input.close();
    
    // Parse JSON
    SimpleJSON::Parser parser;
    auto root = parser.parse(json_str);
    
    if (!root.is_object()) {
        std::cerr << "ERROR: Invalid JSON format" << std::endl;
        return 1;
    }
    
    // Parse settings
    Settings settings;
    auto settings_obj = root["settings"];
    if (settings_obj.is_object()) {
        if (settings_obj["kerf"].is_number()) {
            settings.kerf_width = settings_obj["kerf"].as_number();
        }
        if (settings_obj["allow_rotation"].is_bool()) {
            settings.allow_rotation = settings_obj["allow_rotation"].as_bool();
        }
    }
    
    std::cout << "Settings: kerf=" << settings.kerf_width 
              << "mm, allow_rotation=" << settings.allow_rotation << std::endl;
    
    // Parse boards
    std::map<std::string, std::pair<double, double>> board_sizes;
    auto boards_array = root["boards"];
    if (boards_array.is_array()) {
        for (size_t i = 0; i < boards_array.size(); i++) {
            auto board = boards_array[i];
            std::string material = board["material"].as_string();
            double width = board["width"].as_number();
            double height = board["height"].as_number();
            board_sizes[material] = {width, height};
        }
    }
    
    // Parse parts and group by material
    std::map<std::string, std::vector<Part>> parts_by_material;
    auto parts_array = root["parts"];
    if (parts_array.is_array()) {
        for (size_t i = 0; i < parts_array.size(); i++) {
            auto part_obj = parts_array[i];
            
            Part part;
            part.id = part_obj["id"].as_string();
            part.material = part_obj["material"].as_string();
            part.width = part_obj["width"].as_number();
            part.height = part_obj["height"].as_number();
            
            std::string grain = part_obj["grain_direction"].as_string();
            if (grain.empty()) grain = "any";
            part.grain_direction = grain;
            
            if (settings.allow_rotation) {
                part.allowed_rotations = parse_grain_direction(grain);
            } else {
                part.allowed_rotations = {0};
            }
            
            parts_by_material[part.material].push_back(part);
        }
    }
    
    std::cout << "Loaded " << parts_array.size() << " parts across " 
              << parts_by_material.size() << " materials" << std::endl;
    
    // Run nesting for each material
    Nester nester(settings);
    std::vector<Board> all_boards;
    
    for (auto& [material, parts] : parts_by_material) {
        std::cout << "\n=== Processing material: " << material << " ===" << std::endl;
        
        auto board_size_it = board_sizes.find(material);
        double board_width = 2440.0;
        double board_height = 1220.0;
        
        if (board_size_it != board_sizes.end()) {
            board_width = board_size_it->second.first;
            board_height = board_size_it->second.second;
        }
        
        auto boards = nester.nest_parts(parts, material, board_width, board_height);
        all_boards.insert(all_boards.end(), boards.begin(), boards.end());
    }
    
    auto end_time = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time);
    
    std::cout << "\n=== Nesting Complete ===" << std::endl;
    std::cout << "Total boards: " << all_boards.size() << std::endl;
    std::cout << "Time: " << duration.count() << "ms" << std::endl;
    
    // Write output JSON
    std::ofstream output(output_file);
    if (!output.is_open()) {
        std::cerr << "ERROR: Cannot open output file: " << output_file << std::endl;
        return 1;
    }
    
    output << "{\n";
    output << "  \"placements\": [\n";
    
    bool first_placement = true;
    for (const auto& board : all_boards) {
        for (const auto* part : board.placed_parts) {
            if (!first_placement) output << ",\n";
            first_placement = false;
            
            output << "    {\n";
            output << "      \"part_id\": \"" << SimpleJSON::escape_string(part->id) << "\",\n";
            output << "      \"board_id\": " << part->board_id << ",\n";
            output << "      \"x\": " << part->x << ",\n";
            output << "      \"y\": " << part->y << ",\n";
            output << "      \"rotation\": " << part->rotation << "\n";
            output << "    }";
        }
    }
    
    output << "\n  ],\n";
    output << "  \"boards\": [\n";
    
    for (size_t i = 0; i < all_boards.size(); i++) {
        const auto& board = all_boards[i];
        if (i > 0) output << ",\n";
        
        output << "    {\n";
        output << "      \"id\": " << board.id << ",\n";
        output << "      \"material\": \"" << SimpleJSON::escape_string(board.material) << "\",\n";
        output << "      \"width\": " << board.width << ",\n";
        output << "      \"height\": " << board.height << ",\n";
        output << "      \"parts_count\": " << board.placed_parts.size() << ",\n";
        output << "      \"used_area\": " << board.used_area() << ",\n";
        output << "      \"waste_percentage\": " << board.waste_percentage() << "\n";
        output << "    }";
    }
    
    output << "\n  ],\n";
    output << "  \"stats\": {\n";
    output << "    \"time_ms\": " << duration.count() << ",\n";
    output << "    \"boards_used\": " << all_boards.size() << "\n";
    output << "  }\n";
    output << "}\n";
    
    output.close();
    
    std::cout << "Results written to: " << output_file << std::endl;
    
    return 0;
}
