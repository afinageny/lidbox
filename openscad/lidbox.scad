// Drillbox — sandwich lid: two mirrored trapezoids. Units: millimetres.

/* [Show] */
part = "print"; // [print:print, assembly:assembly, box:box, lid upper:lidSandwichTop, lid lower:lidSandwichBottom]
// Lid open, % (0 = closed)
lid_open = 0; // [0:1:100]

/* [Box] */
// Width (slide direction), mm
width = 80; // [20:1:200]
// Depth, mm
depth = 50; // [20:1:200]
// Height, mm
height = 40; // [15:1:200]
// Thickness, mm
thickness = 3; // [1.5:0.5:12]
// Fillet radius, mm
fillet_radius = 1.5; // [0:0.1:6]

/* [Lid] */
// Lid thickness, mm (0 = half wall thickness)
lid_thickness = 0; // [0:0.5:8]
// Dovetail angle, °
dovetail_angle = 20; // [8:1:35]
// Clearance, mm
clearance = 0.1; // [0.1:0.05:0.8]
// Peg diameter, mm
peg_diameter = 1.6; // [1.2:0.1:2.4]

/* [Windows] */
// Window count X
window_count_x = 2; // [1:6]
// Window count Y
window_count_y = 1; // [1:6]
// Frame width, mm
frame_width = 5; // [2:1:15]
// Window lip, mm
window_lip = 2; // [1:0.5:5]
// Sheet thickness, mm
sheet_thickness = 1; // [0.3:0.1:1]

/* [Colors] */
// Color box
color_box = "#d97757";
// Color lid upper
color_lid_upper = "#6bcb77";
// Color lid lower
color_lid_lower = "#2f6f4e";

$fa = $preview ? 8 : 5;
$fs = $preview ? 0.8 : 0.4;

function wall() = min(thickness, width / 2 - 0.8, depth / 2 - 0.8, height - 1);
function fillet_r() =
    min(
        max(0, fillet_radius),
        wall() / 2,
        width / 2 - 0.4,
        depth / 2 - 0.4,
        height / 2 - 0.4
    );
function lid_h() = min(lid_thickness > 0 ? lid_thickness : wall() / 2, (height - wall() - 1) / 2);
function end_fillet_r() = fillet_r();
function flare() = min(lid_h() * tan(dovetail_angle), wall() - 0.8);
function y_top() = depth / 2 - wall();
function y_bot() = y_top() + flare();
function lid_c() = min(clearance, flare() / 3, lid_h() / 4);
function stop_keep() = max(0.8, wall() - fillet_r());
function lid_len() = width - stop_keep() - lid_c();
function groove_len() = width - stop_keep();
function yt() = y_top() - lid_c();
function yb() = y_bot() - lid_c();
function lid_travel() = lid_len();
function stack_h() = 2 * lid_h();

function win_nx() = max(1, round(window_count_x));
function win_ny() = max(1, round(window_count_y));
function frame_x0() = frame_width + wall() - lid_c();
function frame_x1() = max(frame_width, frame_width + wall() - stop_keep());
function win_wx() = max(1, (lid_len() - frame_x0() - frame_x1() - (win_nx() - 1) * frame_width) / win_nx());
function win_wy() = max(1, (2 * yt() - (win_ny() + 1) * frame_width) / win_ny());
function win_cx(i) = frame_x0() + win_wx() / 2 + i * (win_wx() + frame_width);
function win_cy(j) = -yt() + frame_width + win_wy() / 2 + j * (win_wy() + frame_width);
function pocket_d() = min(sheet_thickness / 2 + 0.15, lid_h() - 0.8);
function pocket_wx() = win_wx() + 2 * window_lip;
function pocket_wy() = min(win_wy() + 2 * window_lip, 2 * yb() - 2);
function peg_h() = min(lid_h() / 2, lid_h() - 0.8);
function peg_m() = min(
    max(1.5, fillet_r() + peg_diameter / 2 + 0.4),
    frame_width * 0.45,
    yt() - 1.2
);
function peg_d() = min(peg_diameter, frame_width * 0.45, 2 * peg_m() - 0.6);
function peg_hole() = peg_d() + 0.22;

function peg_x(i) =
    i == 0 ? peg_m() :
    i == win_nx() ? lid_len() - peg_m() :
    frame_x0() - frame_width / 2 + i * (win_wx() + frame_width);

function peg_y(j) =
    j == 0 ? -(yt() - peg_m()) :
    j == win_ny() ? yt() - peg_m() :
    -yt() + j * (win_wy() + frame_width) + frame_width / 2;

module trap_x(len, y_wide, y_narrow, h) {
    e = min(0.2, h / 5);
    hull() {
        translate([0, -y_wide, 0])
            cube([len, 2 * y_wide, e]);
        translate([0, -y_narrow, h - e])
            cube([len, 2 * y_narrow, e]);
    }
}

module trap_x_inv(len, y_narrow, y_wide, h) {
    e = min(0.2, h / 5);
    hull() {
        translate([0, -y_narrow, 0])
            cube([len, 2 * y_narrow, e]);
        translate([0, -y_wide, h - e])
            cube([len, 2 * y_wide, e]);
    }
}

module rounded_cube(size, r) {
    rr = min(r, size[0] / 2 - 0.05, size[1] / 2 - 0.05, size[2] / 2 - 0.05);
    if (rr < 0.05) {
        cube(size);
    } else {
        hull() {
            for (x = [rr, size[0] - rr], y = [rr, size[1] - rr]) {
                translate([x, y, 0])
                    cylinder(h = max(0.02, size[2] - rr), r = rr);
                translate([x, y, size[2] - rr])
                    sphere(rr);
            }
        }
    }
}

module rounded_cavity(size, r) {
    rr = min(r, size[0] / 2 - 0.05, size[1] / 2 - 0.05);
    if (rr < 0.05) {
        cube(size);
    } else {
        linear_extrude(size[2])
            offset(r = rr)
                offset(delta = -rr)
                    square([size[0], size[1]]);
    }
}

module lid_end_fillets(len, hy, h) {
    r = end_fillet_r();
    if (r > 0.2) {
        translate([0, -hy, h - r])
            difference() {
                translate([-0.05, 0, 0])
                    cube([r + 0.05, 2 * hy, r + 0.05]);
                translate([r, -0.1, 0])
                    rotate([-90, 0, 0])
                        cylinder(h = 2 * hy + 0.2, r = r);
            }
        translate([len, -hy, h - r])
            difference() {
                translate([-r, 0, 0])
                    cube([r + 0.05, 2 * hy, r + 0.05]);
                translate([-r, -0.1, 0])
                    rotate([-90, 0, 0])
                        cylinder(h = 2 * hy + 0.2, r = r);
            }
    }
}

module lid_frame(len, y_narrow, y_wide, h) {
    difference() {
        union() {
            trap_x_inv(len, y_narrow, y_wide, h);
            translate([0, 0, h])
                trap_x(len, y_wide, y_narrow, h);
        }
        translate([0, 0, h])
            lid_end_fillets(len, y_wide + 1, h);
    }
}

module lid_cavity() {
    translate([0, 0, -0.04])
        lid_frame(groove_len(), y_top(), y_bot(), lid_h() + 0.08);
}

module limiter_follow_lid() {
    r = end_fillet_r();
    if (r > 0.2) {
        g = lid_c();
        hy = y_bot() + 1;
        translate([-width / 2 + groove_len() - r, -hy, height - r])
            intersection() {
                translate([r - 0.02, 0, 0])
                    cube([r + g + 0.4, 2 * hy, r + 0.2]);
                rotate([-90, 0, 0])
                    cylinder(h = 2 * hy, r = r + g);
            }
    }
}

module box_lid_groove() {
    r = fillet_r();
    translate([-width / 2, 0, height - stack_h()]) {
        lid_cavity();
        translate([-r - 0.4, 0, 0])
            lid_cavity();
    }
    limiter_follow_lid();
}

module box_body() {
    t = wall();
    r = fillet_r();
    difference() {
        translate([-width / 2, -depth / 2, 0])
            rounded_cube([width, depth, height], r);
        translate([-width / 2 + t, -depth / 2 + t, t])
            rounded_cavity(
                [width - 2 * t, depth - 2 * t, height - stack_h() - t + 0.02],
                r
            );
        box_lid_groove();
    }
}

module lid_top_end_fillets() {
    lid_end_fillets(lid_len(), yb() + 1, lid_h());
}

module window_through() {
    for (i = [0 : win_nx() - 1], j = [0 : win_ny() - 1])
        translate([win_cx(i), win_cy(j), lid_h() / 2])
            cube([win_wx(), win_wy(), lid_h() + 2], center = true);
}

module window_pockets(from_bottom) {
    d = pocket_d();
    z = from_bottom ? -0.02 : lid_h() - d;
    for (i = [0 : win_nx() - 1], j = [0 : win_ny() - 1])
        translate([win_cx(i) - pocket_wx() / 2, win_cy(j) - pocket_wy() / 2, z])
            cube([pocket_wx(), pocket_wy(), d + 0.02]);
}

module peg_at(i, j) {
    translate([peg_x(i), peg_y(j), 0]) children();
}

module pegs_male() {
    h = peg_h();
    d = peg_d();
    for (i = [0 : win_nx()], j = [0 : win_ny()])
        if (i == 0 || i == win_nx() || j == 0 || j == win_ny())
            peg_at(i, j)
                translate([0, 0, -h])
                    cylinder(h = h + 0.02, d1 = d, d2 = d * 0.88, $fn = 20);
}

module pegs_female() {
    h = peg_h();
    for (i = [0 : win_nx()], j = [0 : win_ny()])
        if (i == 0 || i == win_nx() || j == 0 || j == win_ny())
            peg_at(i, j)
                translate([0, 0, lid_h() - h])
                    cylinder(h = h + 0.2, d = peg_hole(), $fn = 20);
}

module lid_upper() {
    difference() {
        union() {
            trap_x(lid_len(), yb(), yt(), lid_h());
            pegs_male();
        }
        window_through();
        window_pockets(true);
        lid_top_end_fillets();
    }
}

module lid_lower() {
    difference() {
        trap_x_inv(lid_len(), yt(), yb(), lid_h());
        window_through();
        window_pockets(false);
        pegs_female();
    }
}

module lid_print() {
    translate([0, 0, lid_h()]) rotate([180, 0, 0]) children();
}

module place_lid(z) {
    translate([-lid_open / 100 * lid_travel(), 0, 0])
        translate([-width / 2 + lid_c(), 0, z])
            children();
}

function layout_gap() = 12;
function frame_x() = width / 2 + 16;
function frame_pitch() = 2 * yb() + layout_gap();

module lid_upper_layout() {
    translate([frame_x(), -frame_pitch() / 2, 0])
        lid_print() lid_upper();
}

module lid_lower_layout() {
    translate([frame_x(), frame_pitch() / 2, 0])
        lid_lower();
}

if (part == "box")
    color(color_box) box_body();
else if (part == "lidSandwichTop")
    color(color_lid_upper) lid_print() lid_upper();
else if (part == "lidSandwichTopLayout")
    color(color_lid_upper) lid_upper_layout();
else if (part == "lidSandwichTopPlaced")
    color(color_lid_upper)
        place_lid(height - lid_h()) lid_upper();
else if (part == "lidSandwichBottom")
    color(color_lid_lower) lid_print() lid_lower();
else if (part == "lidSandwichBottomLayout")
    color(color_lid_lower) lid_lower_layout();
else if (part == "lidSandwichBottomPlaced")
    color(color_lid_lower)
        place_lid(height - stack_h()) lid_lower();
else if (part == "assembly") {
    color(color_box) box_body();
    color(color_lid_upper) place_lid(height - lid_h()) lid_upper();
    color(color_lid_lower) place_lid(height - stack_h()) lid_lower();
} else {
    color(color_box) box_body();
    color(color_lid_upper) lid_upper_layout();
    color(color_lid_lower) lid_lower_layout();
}
