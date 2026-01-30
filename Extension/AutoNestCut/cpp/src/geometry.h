#pragma once

#include <vector>
#include <cmath>

namespace AutoNestCut {

// Rectangle structure: [x, y, width, height]
struct Rect {
    double x;
    double y;
    double width;
    double height;

    Rect() : x(0), y(0), width(0), height(0) {}
    Rect(double x_, double y_, double w_, double h_) 
        : x(x_), y(y_), width(w_), height(h_) {}

    double right() const { return x + width; }
    double bottom() const { return y + height; }
    double area() const { return width * height; }
    bool is_valid() const { return width > 0 && height > 0; }
};

// Check if two rectangles intersect
bool intersects(const Rect& r1, const Rect& r2);

// Subtract r2 from r1, returning up to 4 new rectangles
std::vector<Rect> subtract_rect(const Rect& original, const Rect& to_subtract);

} // namespace AutoNestCut
