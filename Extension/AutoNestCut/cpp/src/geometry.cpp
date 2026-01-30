#include "geometry.h"
#include <algorithm>

namespace AutoNestCut {

bool intersects(const Rect& r1, const Rect& r2) {
    // Rectangles don't intersect if one is completely to the left/right/above/below the other
    return !(r1.right() <= r2.x || 
             r2.right() <= r1.x || 
             r1.bottom() <= r2.y || 
             r2.bottom() <= r1.y);
}

std::vector<Rect> subtract_rect(const Rect& original, const Rect& to_subtract) {
    std::vector<Rect> result;
    
    // Calculate intersection bounds
    double ix1 = std::max(original.x, to_subtract.x);
    double iy1 = std::max(original.y, to_subtract.y);
    double ix2 = std::min(original.right(), to_subtract.right());
    double iy2 = std::min(original.bottom(), to_subtract.bottom());
    
    // No intersection - return original
    if (ix2 <= ix1 || iy2 <= iy1) {
        result.push_back(original);
        return result;
    }
    
    // Create up to 4 rectangles around the intersection
    
    // 1. Left piece (to the left of intersection)
    if (original.x < ix1) {
        result.emplace_back(
            original.x, 
            original.y, 
            ix1 - original.x, 
            original.height
        );
    }
    
    // 2. Right piece (to the right of intersection)
    if (original.right() > ix2) {
        result.emplace_back(
            ix2, 
            original.y, 
            original.right() - ix2, 
            original.height
        );
    }
    
    // 3. Bottom piece (below intersection, constrained by intersection X-bounds)
    if (original.y < iy1) {
        result.emplace_back(
            ix1, 
            original.y, 
            ix2 - ix1, 
            iy1 - original.y
        );
    }
    
    // 4. Top piece (above intersection, constrained by intersection X-bounds)
    if (original.bottom() > iy2) {
        result.emplace_back(
            ix1, 
            iy2, 
            ix2 - ix1, 
            original.bottom() - iy2
        );
    }
    
    return result;
}

} // namespace AutoNestCut
