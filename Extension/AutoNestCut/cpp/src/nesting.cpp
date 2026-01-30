#include "nesting.h"
#include <algorithm>
#include <iostream>

namespace AutoNestCut {

Nester::Nester(const Settings& settings) : settings_(settings) {}

bool Board::find_best_position(double part_width, double part_height, 
                               double kerf, double& out_x, double& out_y) {
    // Special case: exact fit on empty board (no kerf needed)
    if (placed_parts.empty() && 
        std::abs(part_width - width) < 0.1 && 
        std::abs(part_height - height) < 0.1) {
        out_x = 0;
        out_y = 0;
        return true;
    }
    
    double effective_width = part_width + kerf;
    double effective_height = part_height + kerf;
    
    // Try each free rectangle (already sorted by Y then X for bottom-left preference)
    for (const auto& rect : free_rectangles) {
        if (effective_width <= rect.width && effective_height <= rect.height) {
            // Check board boundaries
            if (rect.x + effective_width <= width && 
                rect.y + effective_height <= height) {
                out_x = rect.x;
                out_y = rect.y;
                return true;
            }
        }
    }
    
    return false;
}

void Board::add_part(Part* part, double x, double y, double kerf) {
    part->x = x;
    part->y = y;
    part->board_id = id;
    placed_parts.push_back(part);
    
    // Rectangle occupied by part + kerf
    double w, h;
    part->get_rotated_dimensions(part->rotation, w, h);
    Rect placed_rect(x, y, w + kerf, h + kerf);
    
    // Update free rectangles
    std::vector<Rect> updated_free_rects;
    
    for (const auto& free_rect : free_rectangles) {
        if (intersects(free_rect, placed_rect)) {
            // Subtract placed rectangle from free rectangle
            auto new_rects = subtract_rect(free_rect, placed_rect);
            for (const auto& r : new_rects) {
                if (r.is_valid()) {
                    updated_free_rects.push_back(r);
                }
            }
        } else {
            // No intersection, keep as is
            updated_free_rects.push_back(free_rect);
        }
    }
    
    free_rectangles = std::move(updated_free_rects);
    
    // Sort by Y then X for bottom-left preference
    std::sort(free_rectangles.begin(), free_rectangles.end(),
        [](const Rect& a, const Rect& b) {
            if (std::abs(a.y - b.y) < 0.01) {
                return a.x < b.x;
            }
            return a.y < b.y;
        });
}

double Board::used_area() const {
    double total = 0;
    for (const auto* part : placed_parts) {
        total += part->area();
    }
    return total;
}

double Board::waste_percentage() const {
    double total = width * height;
    if (total == 0) return 0;
    return ((total - used_area()) / total) * 100.0;
}

bool Nester::try_place_part(Part& part, Board& board) {
    // Store original state
    double original_width = part.width;
    double original_height = part.height;
    int original_rotation = part.rotation;
    
    // Try each allowed rotation
    for (int rotation : part.allowed_rotations) {
        part.rotation = rotation;
        
        double w, h;
        part.get_rotated_dimensions(rotation, w, h);
        
        double x, y;
        if (board.find_best_position(w, h, settings_.kerf_width, x, y)) {
            board.add_part(&part, x, y, settings_.kerf_width);
            return true;
        }
    }
    
    // Restore original state if placement failed
    part.width = original_width;
    part.height = original_height;
    part.rotation = original_rotation;
    
    return false;
}

std::vector<Board> Nester::nest_parts(
    std::vector<Part>& parts,
    const std::string& material,
    double board_width,
    double board_height) {
    
    std::vector<Board> boards;
    
    // Sort parts by area (largest first) for better packing
    std::sort(parts.begin(), parts.end(),
        [](const Part& a, const Part& b) {
            return a.area() > b.area();
        });
    
    std::vector<Part*> remaining_parts;
    for (auto& part : parts) {
        remaining_parts.push_back(&part);
    }
    
    int board_count = 0;
    size_t total_parts = parts.size();
    size_t placed_count = 0;
    
    std::cout << "Starting nesting for " << total_parts << " parts on material: " 
              << material << std::endl;
    
    while (!remaining_parts.empty()) {
        board_count++;
        boards.emplace_back(board_count, material, board_width, board_height);
        Board& current_board = boards.back();
        
        std::vector<Part*> parts_for_next_board;
        
        for (Part* part : remaining_parts) {
            if (try_place_part(*part, current_board)) {
                placed_count++;
                
                // Progress reporting every 10 parts or at end
                if (placed_count % 10 == 0 || placed_count == total_parts) {
                    std::cout << "Progress: " << placed_count << "/" << total_parts 
                              << " parts placed on " << board_count << " boards" << std::endl;
                }
            } else {
                parts_for_next_board.push_back(part);
            }
        }
        
        // Check if we made progress
        if (current_board.placed_parts.empty()) {
            // No parts could be placed - error condition
            if (!remaining_parts.empty()) {
                Part* problem_part = remaining_parts[0];
                std::cerr << "ERROR: Unable to place part '" << problem_part->id 
                          << "' (" << problem_part->width << "x" << problem_part->height 
                          << "mm) on board (" << board_width << "x" << board_height 
                          << "mm) for material '" << material << "'" << std::endl;
                boards.pop_back(); // Remove empty board
                break;
            }
        }
        
        remaining_parts = std::move(parts_for_next_board);
    }
    
    std::cout << "Nesting complete: " << placed_count << "/" << total_parts 
              << " parts placed on " << boards.size() << " boards" << std::endl;
    
    return boards;
}

} // namespace AutoNestCut
