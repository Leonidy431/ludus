// ============================================================================
// AUTO-GENERATED from rov-platform/interfaces/central_control_layout.json
// by rov-platform/interfaces/generate_scad_coords.py - DO NOT HAND-EDIT.
// Re-run the generator after changing the JSON; commit both together.
// ============================================================================

board_width_mm = 70.0;
board_height_mm = 50.0;
board_thickness_mm = 1.6;
standoff_height_mm = 6.0;

// [x_mm, y_mm, hole_diameter_mm] per standoff, board-local coordinates.
standoffs = [
    [5.0, 5.0, 3.2],  // SO1_bl (M3)
    [65.0, 5.0, 3.2],  // SO2_br (M3)
    [5.0, 45.0, 3.2],  // SO3_tl (M3)
    [65.0, 45.0, 3.2]  // SO4_tr (M3)
];

// [edge_x_mm, edge_y_mm, shape, dim1_mm, dim2_mm] per connector panel cutout.
// shape "rect": dim1=width, dim2=height. shape "circle": dim1=dim2=diameter.
connector_cutouts = [
    [0.0, 25.0, "rect", 16.0, 8.5],  // PWR_XT60
    [70.0, 15.0, "rect", 9.5, 3.5],  // USB_DATA
    [70.0, 35.0, "circle", 12.0, 12.0]  // I2C_SENSOR_HDR
];
