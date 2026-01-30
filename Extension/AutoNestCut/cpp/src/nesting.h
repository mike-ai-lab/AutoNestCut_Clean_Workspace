#pragma once

#include "geometry.h"
#include <string>
#include <vector>
#include <memory>

namespace AutoNestCut {

// Part to be placed
struct Part {
    std::string id;
    std::string material;
    double width;
    double height;
    std::string grain_direction;
    std::vector<int> allowed_rotations; // 0, 90, 180, 270
    
    // Placement result (filled by nesting algorithm)
    double x = 0;
    double y = 0;
    int rotation = 0;
    int board_id = -1;
    
    double area() const { return width * height; }
    
    // Get dimensions after rotation
    void get_rotated_dimensions(int rot, double& w, double& h) const {
        if (rot == 90 || rot == 270) {
            w = height;
            h = width;
        } else {
            w = width;
            h = height;
        }
    }
};

// Board (sheet stock)
struct Board {
    int id;
    std::string material;
    double width;
    double height;
    std::vector<Rect> free_rectangles;
    std::vector<Part*> placed_parts;
    
    Board(int id_, const std::string& mat, double w, double h)
        : id(id_), material(mat), width(w), height(h) {
        // Initialize with one large free rectangle
        free_rectangles.emplace_back(0, 0, w, h);
    }
    
    // Find best position for a part with given dimensions
    bool find_best_position(double part_width, double part_height, 
                           double kerf, double& out_x, double& out_y);
    
    // Add part to board and update free rectangles
    void add_part(Part* part, double x, double y, double kerf);
    
    double used_area() const;
    double waste_percentage() const;
};

// Nesting settings
struct Settings {
    double kerf_width = 3.0;
    bool allow_rotation = true;
    int timeout_ms = 60000;
};

// Main nesting engine
class Nester {
public:
    Nester(const Settings& settings);
    
    // Nest parts onto boards
    // Returns list of boards with placed parts
    std::vector<Board> nest_parts(
        std::vector<Part>& parts,
        const std::string& material,
        double board_width,
        double board_height
    );
    
private:
    Settings settings_;
    
    bool try_place_part(Part& part, Board& board);
};

} // namespace AutoNestCut
