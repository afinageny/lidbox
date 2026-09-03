// Parametric drill plate + waterCover, same geometry as create_rect_n_holes_inner.py
// Units: millimetres. Open in OpenSCAD Customizer to pick a part and tweak sizes.

/* [Show] */
part = "assembly"; // [assembly, drillTemplate, waterCover, hoseFitting, drainPlug]
show_threads = true;

/* [Holes] */
// Hole count
hole_count = 2; // [1:8]
// Hole diameter, mm
hole_diameter = 78; // [20:0.5:150]
// Rim, mm
rim = 10; // [2:40]
// Hole offset, mm
hole_offset = 71; // [20:0.5:200]

/* [Plate] */
// Margin, mm
margin = 20; // [5:80]
// Thickness, mm
thickness = 10; // [4:30]
// Corner fillet, mm
corner_fillet = 6; // [0:20]
// Edge fillet, mm
edge_fillet = 2; // [0:8]
// Corner inset, mm
corner_inset = 10; // [4:40]
// Corner hole diameter, mm
corner_hole_d = 5; // [2:0.5:12]

/* [Cover] */
// Wall height, mm
wall_height = 50; // [10:120]
// Wall thickness, mm
wall_thickness = 3; // [1:0.5:10]
// Thread boss length, mm (G 1/2)
thread_boss_length = 12; // [6:30]
// Lid hole oversize, mm
lid_hole_oversize = 10; // [0:40]
fitting_barb_22 = 22; // [10:40]
fitting_barb_19 = 19; // [10:40]
fitting_bore = 12; // [4:20]
fitting_hex = 27; // [12:40]

/* [Hidden] */
G12_PITCH = 1.814;
G12_MAJOR = 20.955;
G12_MINOR = 18.631;
FITTING_HEX_H = 7;
FITTING_TOOTH = 4.5;

wall_inset = edge_fillet;

$fa = $preview ? 8 : 5;
$fs = $preview ? 1.2 : 0.6;

function plate_w() = 2 * margin + hole_diameter + (hole_count - 1) * hole_offset;
function plate_h() = 2 * margin + hole_diameter;
function hole_x(i) = -(hole_count - 1) * hole_offset / 2 + i * hole_offset;

module rounded_rect_2d(w, h, r) {
    offset(r = r)
        offset(delta = -r)
            square([w, h], center = true);
}

function corner_xy() = [
    [plate_w() / 2 - corner_inset, plate_h() / 2 - corner_inset],
    [plate_w() / 2 - corner_inset, -(plate_h() / 2 - corner_inset)],
    [-(plate_w() / 2 - corner_inset), plate_h() / 2 - corner_inset],
    [-(plate_w() / 2 - corner_inset), -(plate_h() / 2 - corner_inset)]
];

// Straight sides; at each screw a quarter-circle wrap (holes stay outside).
module notched_2d(inset, wrap) {
    ox = plate_w() / 2 - inset;
    oy = plate_h() / 2 - inset;
    hx = plate_w() / 2 - corner_inset;
    hy = plate_h() / 2 - corner_inset;
    union() {
        square([2 * (hx - wrap), 2 * oy], center = true);
        square([2 * ox, 2 * (hy - wrap)], center = true);
        wrap_bridge(hx, hy, wrap);
        wrap_bridge(hx, -hy, wrap);
        wrap_bridge(-hx, hy, wrap);
        wrap_bridge(-hx, -hy, wrap);
    }
}

module wrap_bridge(cx, cy, wrap) {
    difference() {
        translate([
            cx > 0 ? cx - wrap : cx,
            cy > 0 ? cy - wrap : cy
        ])
            square([wrap, wrap]);
        translate([cx, cy])
            circle(r = wrap);
    }
}

module wall_outer_2d() {
    notched_2d(wall_inset, corner_inset);
}

module wall_cavity_2d() {
    notched_2d(wall_inset + wall_thickness, corner_inset + wall_thickness);
}

module extrude_top_fillet(h, r, steps = 6) {
    linear_extrude(h - r)
        children();
    for (i = [0 : steps - 1]) {
        a0 = 90 * i / steps;
        a1 = 90 * (i + 1) / steps;
        hull() {
            translate([0, 0, h - r + r * sin(a0)])
                linear_extrude(0.02)
                    offset(delta = -r * (1 - cos(a0)))
                        children();
            translate([0, 0, h - r + r * sin(a1)])
                linear_extrude(0.02)
                    offset(delta = -r * (1 - cos(a1)))
                        children();
        }
    }
}

function quarter_arc(c, r, a0, a1, n = 10) = [
    for (i = [0 : n])
        [c[0] + r * cos(a0 + (a1 - a0) * i / n),
         c[1] + r * sin(a0 + (a1 - a0) * i / n)]
];

module boss_ring() {
    r_out = hole_diameter / 2 + rim;
    fr = thickness / 2;
    z0 = thickness / 2;
    z1 = thickness;
    pts = concat(
        [[0.02, z0]],
        quarter_arc([r_out - fr, z1 - fr], fr, 0, 90, 10),
        [[0.02, z1]]
    );
    rotate_extrude()
        polygon(pts);
}

module corner_screws(h = thickness / 2 + 0.4) {
    for (p = corner_xy())
        translate([p[0], p[1], -0.2])
            cylinder(h = h, d = corner_hole_d);
}

module thin_plate() {
    extrude_top_fillet(thickness / 2, edge_fillet)
        rounded_rect_2d(plate_w(), plate_h(), corner_fillet);
}

module drill_template() {
    difference() {
        union() {
            thin_plate();
            for (i = [0 : hole_count - 1])
                translate([hole_x(i), 0, 0])
                    boss_ring();
        }
        for (i = [0 : hole_count - 1])
            translate([hole_x(i), 0, -1])
                cylinder(h = thickness + 2, d = hole_diameter);
        corner_screws();
    }
}

module g12_male_thread(h) {
    cylinder(h = h, d = G12_MINOR);
    if (show_threads && h > 0) {
        nseg = max(12, round(h / G12_PITCH * ($preview ? 10 : 18)));
        tooth = (G12_MAJOR - G12_MINOR) / 2;
        hb = 0.38 * G12_PITCH;
        for (i = [0 : nseg - 1]) {
            z0 = i * h / nseg;
            z1 = (i + 1) * h / nseg;
            a0 = 360 * z0 / G12_PITCH;
            a1 = 360 * z1 / G12_PITCH;
            hull() {
                rotate(a0)
                    translate([G12_MINOR / 2, 0, z0])
                        rotate([90, 0, 0])
                            linear_extrude(0.05)
                                polygon([[0, -hb], [tooth, 0], [0, hb]]);
                rotate(a1)
                    translate([G12_MINOR / 2, 0, z1])
                        rotate([90, 0, 0])
                            linear_extrude(0.05)
                                polygon([[0, -hb], [tooth, 0], [0, hb]]);
            }
        }
    }
}

module male_nipple_solid(along_x) {
    outer = along_x ? plate_w() / 2 - wall_inset : plate_h() / 2 - wall_inset;
    z = thickness / 2 + wall_height / 2;
    translate([along_x ? outer : 0, along_x ? 0 : -outer, z])
        rotate(along_x ? [0, 90, 0] : [90, 0, 0])
            g12_male_thread(thread_boss_length);
}

module male_nipple_bore(along_x) {
    outer = along_x ? plate_w() / 2 - wall_inset : plate_h() / 2 - wall_inset;
    z = thickness / 2 + wall_height / 2;
    bore_h = wall_thickness + thread_boss_length + 2;
    translate([along_x ? outer : 0, along_x ? 0 : -outer, z])
        rotate(along_x ? [0, 90, 0] : [90, 0, 0])
            translate([0, 0, -wall_thickness - 1])
                cylinder(h = bore_h, d = fitting_bore);
}

module water_cover() {
    z_walls = thickness / 2;
    z_lid = z_walls + wall_height;
    difference() {
        union() {
            difference() {
                thin_plate();
                translate([0, 0, -1])
                    linear_extrude(thickness / 2 + 2)
                        wall_cavity_2d();
            }
            translate([0, 0, z_walls])
                linear_extrude(wall_height)
                    difference() {
                        wall_outer_2d();
                        wall_cavity_2d();
                    }
            translate([0, 0, z_lid])
                linear_extrude(wall_thickness)
                    wall_outer_2d();
            male_nipple_solid(true);
            male_nipple_solid(false);
        }
        corner_screws();
        for (i = [0 : hole_count - 1])
            translate([hole_x(i), 0, z_lid - 1])
                cylinder(h = wall_thickness + 2, d = hole_diameter + lid_hole_oversize);
        male_nipple_bore(true);
        male_nipple_bore(false);
    }
}

module hex_pad(af, h) {
    cylinder(h = h, d = af / cos(30), $fn = 6);
}

module g12_female_socket(depth) {
    difference() {
        translate([0, 0, -depth])
            cylinder(h = depth, d = G12_MAJOR + 7);
        translate([0, 0, -depth - 0.2])
            g12_male_thread(depth + 0.4);
        translate([0, 0, -depth - 0.2])
            cylinder(h = depth + 0.4, d = G12_MINOR);
    }
}

function barb_teeth(d, z0, n = 3) = [
    for (i = [0 : n - 1])
        for (p = [
            [d / 2 - 0.9, z0 + i * FITTING_TOOTH],
            [d / 2 + 0.7, z0 + i * FITTING_TOOTH + 1.1],
            [d / 2 - 0.9, z0 + (i + 1) * FITTING_TOOTH]
        ]) p
];

module hose_fitting() {
    d22 = fitting_barb_22;
    d19 = fitting_barb_19;
    z0 = FITTING_HEX_H + 1.5;
    teeth22 = barb_teeth(d22, z0);
    z1 = z0 + 3 * FITTING_TOOTH + 0.6;
    teeth19 = barb_teeth(d19, z1);
    z2 = z1 + 3 * FITTING_TOOTH;
    barb = concat(
        [[0, FITTING_HEX_H], [d22 / 2 - 0.4, FITTING_HEX_H]],
        teeth22,
        teeth19,
        [[fitting_bore / 2 + 0.6, z2 + 3], [0, z2 + 3]]
    );
    difference() {
        union() {
            hex_pad(fitting_hex, FITTING_HEX_H);
            g12_female_socket(thread_boss_length);
            rotate_extrude()
                polygon(barb);
        }
        translate([0, 0, -thread_boss_length - 1])
            cylinder(h = thread_boss_length + FITTING_HEX_H + 80, d = fitting_bore);
    }
}

module drain_plug() {
    union() {
        hex_pad(fitting_hex, FITTING_HEX_H);
        g12_female_socket(thread_boss_length);
    }
}

module assembly() {
    drill_template();
    translate([plate_w() + margin, 0, 0])
        water_cover();
    translate([
        plate_w() + margin + plate_w() / 2 - wall_inset + thread_boss_length + 30,
        0,
        thread_boss_length
    ])
        hose_fitting();
    translate([
        plate_w() + margin,
        -(plate_h() / 2 - wall_inset) - thread_boss_length - 30,
        thread_boss_length
    ])
        drain_plug();
}

if (part == "drillTemplate")
    drill_template();
else if (part == "waterCover")
    water_cover();
else if (part == "hoseFitting")
    hose_fitting();
else if (part == "drainPlug")
    drain_plug();
else
    assembly();