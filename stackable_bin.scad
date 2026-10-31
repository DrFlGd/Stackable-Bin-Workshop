/*
  Parametric stackable screw box
  Reconstructed from the supplied S / M / L DXF sets.

  Units: millimetres.

  The source DXFs correspond approximately to nominal stack-pitch sizes:
      S = [ 90, 120,  80]  // width, depth, height
      M = [120, 160, 100]
      L = [150, 200, 120]

  Their raw 2D extents vary slightly with stock thickness because of rounded
  corners, joinery and stacking keys.  This model instead treats bin_size as
  the nominal outside width/depth and stacking pitch height, so changing the
  wood thickness does not unexpectedly resize the requested bin.

  Main outputs:
      output = "layout"    -> flat CNC parts, suitable for DXF export
      output = "assembly"  -> 3D assembly preview
      output = "side"      -> one side panel
      output = "back"      -> back panel
      output = "bottom"    -> bottom panel
      output = "front"     -> sloping front panel
      output = "top"       -> optional fixed top panel
      output = "lid"       -> optional hinged front lid

  CNC relief:
      relief_type = "none", "dogbone", or "tbone".
      Every relief arc is generated from bit_diameter / 2.
      Dogbones use a 45-degree cutter-center excursion.
      T-bones put the cutter center on the joint edge, one cutter radius
      from the corner, preserving the nominal tab/slot end position.
      Stacking registration is a smooth mating S-curve, separate from the
      dogbone/T-bone joint reliefs. Its concave radius is never smaller than
      bit_diameter/2, so the selected cutter can machine the profile.

  Suggested workflow:
      1. Set preset or custom_size.
      2. Set wood_thickness to measured material thickness.
      3. Set bit_diameter to the actual cutter diameter.
      4. Set output="layout" and Export -> DXF in OpenSCAD.
*/

$fn = 48;
inch = 25.4;

// ----------------------------- User parameters -----------------------------
preset = "M";                 // [S,M,L,custom]
custom_size = [120,160,100];   // [outside width, outside depth, stack pitch height]
wood_thickness = 0.25*inch;    // measure the actual sheet for best fit
bit_diameter = 3.70;           // actual cutter diameter; defines every relief arc
relief_type = "tbone";         // [none,dogbone,tbone]
fit_clearance = 0.15;          // added to female slot width and length
stack_clearance = 0.40;        // gap per side between stacking keys and recesses
output = "layout";             // [layout,assembly,side,back,bottom,front,top,lid,relief_test,fit_coupon,fit_check]
layout_gap = 12;

// Optional closure pieces.
include_top = false;           // fixed horizontal top panel
include_lid = false;           // hinged lid over the upper-front opening
lid_open_angle = 0;            // degrees; 0 = closed, positive = opens upward/front
lid_side_clearance = 0.75;     // clearance per side between lid and side walls
lid_end_clearance = 0.0;       // gap between closed lid and the front panel's top edge; 0 = lid rests on it
lid_hinge_gap = 1.0;           // gap between the lid's hinge end and the top panel's front edge
top_web = 2.0;                 // side-wall material left above the top-panel mortise
fit_stacked = false;           // fit_check: test against a second bin stacked on top

// Design parameters recovered/generalized from the DXFs.
stack_key_height = 3.0;
edge_land = 9.0;               // material left outside bottom/back panel centreline
front_angle = 44;              // degrees from horizontal, rising toward bin front
front_panel_ratio = 0.375;     // front panel length ~= 3/8 of depth
floor_front_ratio = 0.300;     // floor begins ~= 30% of depth from front
rear_corner_radius = 10;       // outside rear side-panel radius
nose_gap_ratio = 0.085;        // short vertical nose as fraction of height

// ----------------------------- Derived values ------------------------------
size = preset == "S" ? [90,120,80] :
       preset == "M" ? [120,160,100] :
       preset == "L" ? [150,200,120] : custom_size;

W = size[0];
D = size[1];
H = size[2];
t = wood_thickness;
r = bit_diameter/2;

floor_front = floor_front_ratio*D;
bottom_z = edge_land + t/2;
back_y = D - edge_land - t/2;
front_len = front_panel_ratio*D;

// Keep the sloping panel inside the side silhouette for very shallow custom bins.
front_len_safe = min(front_len, (floor_front-2)/max(0.01,cos(front_angle)));

// Front panel frame in side-panel [y,z] coordinates: its centerline starts at
// front_origin and runs along front_dir; front_in points into the bin.
front_origin = [floor_front, bottom_z];
front_dir = [-cos(front_angle), sin(front_angle)];
front_in = [sin(front_angle), cos(front_angle)];

// The front panel's square-cut lower end reaches sin(front_angle)*t/2 behind
// floor_front, so the bottom panel starts there instead of overlapping it.
floor_start = floor_front + sin(front_angle)*t/2;
bottom_depth = (back_y - t/2) - floor_start;

// Reach of a slot's cutter relief beyond its long wall.
function relief_reach(cutter=bit_diameter, relief=relief_type) =
    relief == "tbone" ? cutter/2 :
    relief == "dogbone" ? cutter/2*(1-1/sqrt(2)) : 0;

// Optional top/lid geometry. The top panel is recessed below the stacking rim
// so its mortise (and relief) stays enclosed in the side wall, clear of the
// stacking keys.
top_surface = H - (fit_clearance/2 + relief_reach() + top_web);
top_z = top_surface - t/2;                           // panel centerline

// Lid, in side-panel [y,z] coordinates. Closed, it lies in the plane just past
// the front panel's top end face, so that end face is the lid's stop. The
// hinge axis is the lid's outer edge at the hinge end, level with the top
// panel's upper face, where a surface-mounted hinge's knuckle sits.
lid_plane = front_len_safe + lid_end_clearance;      // lid inner face, along front_dir
lid_outer = lid_plane + t;
lid_near = (top_surface - front_origin[1] - lid_outer*front_dir[1]) / front_in[1];
// Far end flush with the front panel's outer face, unless that would poke
// past the front of the side panels.
lid_far = max(-t/2, -(front_origin[0] + lid_outer*front_dir[0]) / front_in[0]);
lid_hinge = front_origin + lid_outer*front_dir + lid_near*front_in;
lid_inner_corner = lid_hinge - t*front_dir;
lid_far_outer = front_origin + lid_outer*front_dir + lid_far*front_in;
lid_length = lid_near - lid_far;
lid_width = max(10, W - 2*t - 2*lid_side_clearance);
// Where the lid's outer face meets the stacking rim; the side profile follows
// the lid's outer face from here down to its far end.
lid_rim = lid_hinge + (H-top_surface)/front_in[1]*front_in;

top_front = include_lid ? lid_inner_corner[0] + lid_hinge_gap : floor_front;
top_depth = (back_y - t/2) - top_front;

function clamp(v, lo, hi) = min(max(v,lo),hi);
function tab_count(span) = span > 110 ? 2 : 1;
function tab_centers(span, n) = n == 1 ? [span/2] : [span/4, 3*span/4];
function back_tab_length(span,n) = n == 1 ? clamp(span/4 + 10, 24, 40) : clamp(span/6, 18, 30);
function bottom_tab_length(span,n) = n == 1 ? clamp(0.40*span, 24, 40) : clamp(span/4, 24, 32);
function front_tab_length(span) = span >= 70 ? 30 : span >= 55 ? 20 : clamp(span/2.6, 16, 20);

back_n = tab_count(H);
back_centers = tab_centers(H, back_n);
back_tab = back_tab_length(H,back_n);

bottom_n = tab_count(bottom_depth);
bottom_centers = tab_centers(bottom_depth,bottom_n);
bottom_tab = bottom_tab_length(bottom_depth,bottom_n);
front_tab = front_tab_length(front_len_safe);

top_n = tab_count(top_depth);
top_centers = tab_centers(top_depth, top_n);
top_tab = bottom_tab_length(top_depth, top_n);

assert(W > 2*t + 20, "bin width is too small for this stock thickness");
assert(D > 50, "bin depth is too small");
assert(H > 35, "bin height is too small");
assert(bottom_depth > 25, "bottom panel became too short; increase depth or reduce edge_land");
assert(bit_diameter > 0, "bit_diameter must be positive");
assert(!(include_top || include_lid || output == "top") || top_depth > 25,
       "top panel became too short; increase depth or reduce edge_land");
assert(lid_open_angle >= 0 && lid_open_angle <= 140,
       "lid_open_angle must be between 0 and 140 degrees");
assert(!include_lid || lid_length > 15,
       "lid became too short; increase height or depth");
assert(!include_lid || lid_far < t/2,
       "lid no longer covers the front panel's top edge");
assert(bottom_z - (t+fit_clearance)/2 - relief_reach() > stack_key_height + stack_clearance + 1,
       "bottom mortise runs into the stacking recess; increase edge_land");
assert(relief_type == "none" || relief_type == "dogbone" || relief_type == "tbone",
       "relief_type must be none, dogbone, or tbone");

// ------------------------------ 2D helpers ---------------------------------
module capsule_x(len, rad) {
    // Capsule centered at origin, long direction X, total width 2*rad.
    hull() {
        translate([-max(0,len/2-rad),0]) circle(r=rad);
        translate([ max(0,len/2-rad),0]) circle(r=rad);
    }
}

module relieved_slot(length, width, cutter=bit_diameter, relief=relief_type) {
    // Long direction is local X.  The square() is the nominal mortise.
    // Relief circles represent the actual cutter diameter.
    rr = cutter/2;
    db = rr/sqrt(2);

    union() {
        square([length,width],center=true);

        if (rr > 0 && relief == "dogbone") {
            // Minimal dogbone: move the cutter center toward each internal
            // corner along the 45-degree bisector until the cutter reaches it.
            // The center stays inside the mortise, while the cutter sweeps a
            // small diagonal lobe beyond both nominal walls.
            for (sx=[-1,1], sy=[-1,1])
                translate([
                    sx*(length/2-db),
                    sy*(width/2-db)
                ]) circle(r=rr);
        }
        else if (rr > 0 && relief == "tbone") {
            // T-bone: cutter center lies on the long wall and one radius
            // inboard from the slot end.  This clears the square corner while
            // keeping the nominal mortise length unchanged.
            for (sx=[-1,1], sy=[-1,1])
                translate([
                    sx*(length/2-rr),
                    sy*width/2
                ]) circle(r=rr);
        }
    }
}

module shoulder_relief(corner=[0,0], void_dir=[1,1], cutter=bit_diameter, relief=relief_type) {
    // Relief for a concave corner on an OUTER profile, such as where a male
    // tab meets the panel body.  This module is intended to be SUBTRACTED.
    // void_dir points from the corner into the already-empty region.
    rr = cutter/2;
    db = rr/sqrt(2);

    if (rr > 0 && relief == "dogbone")
        translate([
            corner[0] + void_dir[0]*db,
            corner[1] + void_dir[1]*db
        ]) circle(r=rr);
    else if (rr > 0 && relief == "tbone")
        // Put the cutter center one radius past the tab shoulder, on the body
        // edge. This makes a true T-bone without moving the tab end position.
        translate([
            corner[0],
            corner[1] + void_dir[1]*rr
        ]) circle(r=rr);
}


// Smooth stacking-registration profile recovered from the original DXFs.
// Each flank is an S-curve: circular arc -> tangent -> opposite circular arc.
// With the default 3 mm key height this closely matches the original M/S
// geometry. For larger cutters the radius broadens automatically.
function stack_curve_radius(height, cutter=bit_diameter) =
    max(height, cutter/2);

function stack_curve_angle(height, radius) =
    min(45, acos(max(-1, min(1, 1-height/(2*radius)))));

function stack_curve_line(height, radius, angle) =
    max(0,
        (height - 2*radius*(1-cos(angle))) /
        max(0.0001, sin(angle)));

function stack_curve_run(height, radius, angle, line_len) =
    2*radius*sin(angle) + line_len*cos(angle);

function stack_arc_points(radius, angle, n=10) =
    [for (i=[0:n])
        [radius*sin(angle*i/n),
         radius*(1-cos(angle*i/n))]];

function stack_transition_points(height, cutter=bit_diameter, n=10) =
    let(
        radius = stack_curve_radius(height,cutter),
        angle = stack_curve_angle(height,radius),
        line_len = stack_curve_line(height,radius,angle),
        run = stack_curve_run(height,radius,angle,line_len),
        arc = stack_arc_points(radius,angle,n),
        arc_end = arc[len(arc)-1],
        line_end = [
            arc_end[0] + line_len*cos(angle),
            arc_end[1] + line_len*sin(angle)
        ]
    )
    concat(
        arc,
        line_len > 0 ? [line_end] : [],
        [for (i=[n-1:-1:0])
            [run-arc[i][0], height-arc[i][1]]]
    );

function stack_transition_run(height, cutter=bit_diameter) =
    let(
        radius = stack_curve_radius(height,cutter),
        angle = stack_curve_angle(height,radius),
        line_len = stack_curve_line(height,radius,angle)
    )
    stack_curve_run(height,radius,angle,line_len);

module stack_registration_profile(width, height, cutter=bit_diameter) {
    // "width" is the desired overall feature width. If a very narrow feature
    // cannot contain the cutter-safe transitions, retain a small flat crest
    // and let the transition geometry grow as needed.
    tr = stack_transition_points(height,cutter,12);
    run = stack_transition_run(height,cutter);
    flat = max(2, width-2*run);
    total = 2*run + flat;

    points = concat(
        [[-total/2,0]],
        [for (p=tr) [-total/2+p[0], p[1]]],
        [[flat/2,height]],
        [for (i=[len(tr)-1:-1:0])
            [total/2-tr[i][0], tr[i][1]]],
        [[total/2,0]]
    );

    polygon(points=points);
}

module stack_key_2d(width, height, cutter=bit_diameter) {
    stack_registration_profile(width,height,cutter);
}

module stack_recess_2d(width, depth, cutter=bit_diameter, clearance=stack_clearance) {
    // The mating lower pocket is the same smooth profile offset by the
    // stacking clearance on the flanks and crest, so stacked bins bear on the
    // panel edges rather than the key crests. No dogbone/T-bone is used for
    // stacking registration.
    offset(delta=clearance)
        stack_registration_profile(width,depth,cutter);
}

module tabbed_panel_base(panel_w, panel_h, centers, tab_len, do_stack=false) {
    // Cross-panels have an inset body W-2t and tabs that reach the bin's
    // outside width.  T-bone shoulder relief is cut into the body.
    difference() {
        union() {
            translate([t,0]) square([panel_w-2*t,panel_h]);
            for (c=centers) {
                translate([0,c-tab_len/2]) square([t,tab_len]);
                translate([panel_w-t,c-tab_len/2]) square([t,tab_len]);
            }
            if (do_stack) {
                key_w = max(2*stack_key_height+2, 0.15*panel_w);
                for (kx=[0.28*panel_w,0.72*panel_w])
                    translate([kx,panel_h])
                        stack_key_2d(key_w,stack_key_height);
            }
        }

        // Cutter relief at the four concave shoulders of each pair of tabs.
        // The relief circle radius is exactly bit_diameter/2.
        for (c=centers) {
            ylo = c-tab_len/2;
            yhi = c+tab_len/2;

            shoulder_relief([t,ylo],          [-1,-1]);
            shoulder_relief([t,yhi],          [-1, 1]);
            shoulder_relief([panel_w-t,ylo],  [ 1,-1]);
            shoulder_relief([panel_w-t,yhi],  [ 1, 1]);
        }

        if (do_stack) {
            key_w = max(2*stack_key_height+2, 0.15*panel_w);
            for (kx=[0.28*panel_w,0.72*panel_w])
                translate([kx,0])
                    stack_recess_2d(key_w,stack_key_height);
        }
    }
}

module rounded_rear_side_body() {
    // Side silhouette: open/sloping front, horizontal floor/top, rounded rear.
    // H is the stacking pitch; top keys project another stack_key_height.
    nose_gap = clamp(nose_gap_ratio*H, 6, 10);
    nose_mid = 0.50*H;
    nose_lo = nose_mid - nose_gap/2;
    nose_hi = nose_mid + nose_gap/2;
    bottom_front = floor_front;
    cr = min(rear_corner_radius, H/4, D/8);

    // With a lid, the upper front edge follows the closed lid's outer face so
    // the lid sits flush between the side walls.
    upper_front = include_lid ?
        concat([[lid_rim[0],H], lid_far_outer],
               lid_far_outer[0] > 0.01 ? [[0,lid_far_outer[1]]] : [])
      : [[floor_front,H], [0,nose_hi]];

    union() {
        polygon(concat(
            [[bottom_front,0], [D-cr,0], [D-cr,H]],
            upper_front,
            [[0,nose_lo]]
        ));
        hull() {
            translate([D-cr,cr]) circle(r=cr);
            translate([D-cr,H-cr]) circle(r=cr);
        }
    }
}

module side_panel_2d() {
    side_key_w = max(2*stack_key_height+2, 0.0875*D);
    top_span = D-floor_front-rear_corner_radius;
    key_x = [floor_front + 0.27*top_span,
             floor_front + 0.72*top_span];

    difference() {
        union() {
            rounded_rear_side_body();
            for (kx=key_x)
                translate([kx,H])
                    stack_key_2d(side_key_w,stack_key_height);
        }

        // Matching lower registration pockets use the same smooth S-curve.
        for (kx=key_x)
            translate([kx,0])
                stack_recess_2d(side_key_w,stack_key_height);

        // Back panel mortises.
        for (cy=back_centers)
            translate([back_y,cy])
                rotate(90)
                    relieved_slot(back_tab+fit_clearance, t+fit_clearance);

        // Bottom panel mortises.
        for (cc=bottom_centers)
            translate([floor_start+cc,bottom_z])
                relieved_slot(bottom_tab+fit_clearance, t+fit_clearance);

        // Optional top-panel mortises. The top piece uses the same side-tab
        // joinery as the bottom panel; include_lid implies include_top because
        // the lid hinge mounts along the top panel's front edge.
        if (include_top || include_lid)
            for (cc=top_centers)
                translate([top_front+cc,top_z])
                    relieved_slot(top_tab+fit_clearance, t+fit_clearance);

        // Sloping front-panel mortise, centered on its side tab.
        translate([
            floor_front-cos(front_angle)*front_len_safe/2,
            bottom_z+sin(front_angle)*front_len_safe/2
        ])
            rotate(180-front_angle)
                relieved_slot(front_tab+fit_clearance, t+fit_clearance);
    }
}

module back_panel_2d() {
    tabbed_panel_base(W,H,back_centers,back_tab,true);
}

module bottom_panel_2d() {
    tabbed_panel_base(W,bottom_depth,bottom_centers,bottom_tab,false);
}

module front_panel_2d() {
    tabbed_panel_base(W,front_len_safe,[front_len_safe/2],front_tab,false);
}

module top_panel_2d() {
    // Horizontal fixed top. Side tabs are identical in construction to the
    // bottom-panel tabs and land in relieved mortises in the side walls.
    tabbed_panel_base(W,top_depth,top_centers,top_tab,false);
}

module lid_panel_2d() {
    // Hardware-hinged front lid. It fits between the side walls and closes
    // onto the top end face of the sloped front panel.
    square([lid_width,lid_length]);
}

// ------------------------------ Flat layout --------------------------------
module flat_layout() {
    side_h = H+stack_key_height;

    side_panel_2d();
    translate([0,side_h+layout_gap]) side_panel_2d();

    translate([D+layout_gap,0]) back_panel_2d();
    translate([D+layout_gap,H+stack_key_height+layout_gap]) bottom_panel_2d();
    translate([D+layout_gap+W+layout_gap,0]) front_panel_2d();

    if (include_top || include_lid)
        translate([D+layout_gap,
                   H+stack_key_height+layout_gap+bottom_depth+layout_gap])
            top_panel_2d();

    if (include_lid)
        translate([D+layout_gap+W+layout_gap,
                   front_len_safe+layout_gap])
            lid_panel_2d();
}

// ----------------------------- Relief test ---------------------------------
module relief_test() {
    test_len = max(28, 5*t);
    test_w = t + fit_clearance;
    gap = 4*bit_diameter + 8;

    difference() {
        translate([-test_len/2-8,-test_w/2-8])
            square([test_len+16, 3*(test_w+gap)]);

        translate([0,0])
            relieved_slot(test_len,test_w,bit_diameter,"none");
        translate([0,test_w+gap])
            relieved_slot(test_len,test_w,bit_diameter,"dogbone");
        translate([0,2*(test_w+gap)])
            relieved_slot(test_len,test_w,bit_diameter,"tbone");
    }
}

// ------------------------------ Fit coupon ---------------------------------
// Cut from scrap to choose fit_clearance and stack_clearance before cutting a
// full sheet. Each slot or recess is marked with 1-4 small holes, matching
// the position of its clearance in the step list.
fit_coupon_steps = [0.00, 0.10, 0.20, 0.30];   // fit_clearance candidates
stack_coupon_steps = [0.20, 0.30, 0.40, 0.50]; // stack_clearance candidates

module coupon_marks(n) {
    for (i=[0:n-1]) translate([i*3,0]) circle(d=1.5);
}

module fit_coupon() {
    tab_len = 20;
    pitch = tab_len + 4*bit_diameter + 10;
    strip_w = len(fit_coupon_steps)*pitch;
    plate_h = t + 30;
    key_w = 14;
    key_pitch = key_w + 16;
    key_strip_w = len(stack_coupon_steps)*key_pitch;

    // Mortise plate.
    difference() {
        square([strip_w, plate_h]);
        for (i=[0:len(fit_coupon_steps)-1]) {
            c = fit_coupon_steps[i];
            translate([(i+0.5)*pitch, plate_h/2])
                relieved_slot(tab_len+c, t+c);
            translate([(i+0.5)*pitch-4, 5]) coupon_marks(i+1);
        }
    }

    // Tab strip: one panel-style tab to try in each mortise.
    translate([0, plate_h+layout_gap])
        tabbed_panel_base(40, 24, [12], tab_len, false);

    // Key strip (top edge) and recess strip (bottom edge).
    translate([0, plate_h+24+2*layout_gap]) {
        square([key_strip_w, 16]);
        for (i=[0:len(stack_coupon_steps)-1])
            translate([(i+0.5)*key_pitch, 16])
                stack_key_2d(key_w, stack_key_height);
    }
    translate([0, plate_h+24+16+stack_key_height+3*layout_gap])
        difference() {
            square([key_strip_w, 16]);
            for (i=[0:len(stack_coupon_steps)-1]) {
                translate([(i+0.5)*key_pitch, 0])
                    stack_recess_2d(key_w, stack_key_height,
                                    clearance=stack_coupon_steps[i]);
                translate([(i+0.5)*key_pitch-4, 11]) coupon_marks(i+1);
            }
        }
}

// ------------------------------ 3D assembly --------------------------------
module side_3d(x0=0) {
    // local 2D [depth,height], extrusion -> global X thickness
    multmatrix([
        [0,0,1,x0],
        [1,0,0,0],
        [0,1,0,0],
        [0,0,0,1]
    ]) linear_extrude(height=t) side_panel_2d();
}

module back_3d() {
    // local [width,height], extrusion -> global Y
    multmatrix([
        [1,0,0,0],
        [0,0,1,back_y-t/2],
        [0,1,0,0],
        [0,0,0,1]
    ]) linear_extrude(height=t) back_panel_2d();
}

module bottom_3d() {
    translate([0,floor_start,bottom_z-t/2])
        linear_extrude(height=t) bottom_panel_2d();
}

module front_3d() {
    // local X -> width; local Y -> up-and-forward slope; local Z -> panel normal.
    ca = cos(front_angle);
    sa = sin(front_angle);
    multmatrix([
        [1, 0,  0, 0],
        [0,-ca, sa, floor_front - sa*t/2],
        [0, sa, ca, bottom_z - ca*t/2],
        [0, 0,  0, 1]
    ]) linear_extrude(height=t) front_panel_2d();
}

module top_3d() {
    translate([0,top_front,top_z-t/2])
        linear_extrude(height=t) top_panel_2d();
}

module lid_3d(angle=lid_open_angle) {
    // External hardware hinge is represented by its pivot axis rather than
    // modeled as a CNC part. The axis is the lid's outer hinge-end edge.
    // Positive angles swing the lid upward and toward the front of the bin.
    // local X -> width; local Y -> away from the hinge; local Z -> into the bin.
    translate([t+lid_side_clearance,lid_hinge[0],lid_hinge[1]])
        rotate([-angle,0,0])
            multmatrix([
                [1, 0,           0,             0],
                [0,-front_in[0],-front_dir[0], 0],
                [0,-front_in[1],-front_dir[1], 0],
                [0, 0,           0,             1]
            ]) linear_extrude(height=t) lid_panel_2d();
}

module part_3d(i, lid_angle=lid_open_angle) {
    if (i == 0) side_3d(0);
    else if (i == 1) side_3d(W-t);
    else if (i == 2) back_3d();
    else if (i == 3) bottom_3d();
    else if (i == 4) front_3d();
    else if (i == 5 && (include_top || include_lid)) top_3d();
    else if (i == 6 && include_lid) lid_3d(lid_angle);
}

module assembly(lid_angle=lid_open_angle) {
    for (i=[0:6]) part_3d(i, lid_angle);
}

// ------------------------------- Fit check ---------------------------------
// Renders every place two parts overlap; an empty result means the assembly
// fits. With fit_stacked, checks this bin (lid at lid_open_angle) against a
// second, closed bin stacked on top instead.
module fit_check() {
    if (fit_stacked)
        intersection() {
            assembly();
            translate([0,0,H]) assembly(0);
        }
    else
        for (i=[0:5], j=[i+1:6])
            intersection() { part_3d(i); part_3d(j); }
}

// How far the lid opens before it hits a bin stacked on top, from a 2D
// separating-axis test of the lid against the upper bin's front, bottom and
// closed lid.
function rot_cw(v, a) = [v[0]*cos(a) + v[1]*sin(a), -v[0]*sin(a) + v[1]*cos(a)];
function rect_pts(o, u, lu, v, lv) = [o, o+lu*u, o+lu*u+lv*v, o+lv*v];
function poly_normals(poly) =
    [for (i=[0:len(poly)-1])
        let(e = poly[(i+1)%len(poly)] - poly[i]) [-e[1], e[0]]];
function poly_span(poly, ax) = [min([for (p=poly) p*ax]), max([for (p=poly) p*ax])];
function polys_overlap(a, b) =
    min([for (ax=concat(poly_normals(a),poly_normals(b)))
        let(pa=poly_span(a,ax), pb=poly_span(b,ax))
            (pa[1] > pb[0]+1e-6 && pb[1] > pa[0]+1e-6) ? 1 : 0]) == 1;

lid_closed_pts = rect_pts(lid_hinge, -front_in, lid_length, -front_dir, t);
function lid_pts(a) = [for (p=lid_closed_pts) lid_hinge + rot_cw(p-lid_hinge, a)];
upper_bin_pts = [for (poly=[
        rect_pts(front_origin - t/2*front_in, front_dir, front_len_safe, front_in, t),
        rect_pts([floor_start, bottom_z-t/2], [1,0], bottom_depth, [0,1], t),
        lid_closed_pts
    ]) [for (p=poly) p + [0,H]]];
function stacked_lid_hits(a) = max([for (poly=upper_bin_pts) polys_overlap(lid_pts(a), poly) ? 1 : 0]);
stacked_lid_limit = let(hits=[for (a=[0:140]) if (stacked_lid_hits(a) == 1) a])
    len(hits) == 0 ? 140 : hits[0] - 1;
if (include_lid) echo(stacked_lid_limit=stacked_lid_limit);
if (include_lid && lid_open_angle > stacked_lid_limit)
    echo(str("NOTE: with a bin stacked on top, the lid only opens to ",
             stacked_lid_limit, " degrees"));

// -------------------------------- Output -----------------------------------
if (output == "layout") flat_layout();
else if (output == "assembly") assembly();
else if (output == "side") side_panel_2d();
else if (output == "back") back_panel_2d();
else if (output == "bottom") bottom_panel_2d();
else if (output == "front") front_panel_2d();
else if (output == "top") top_panel_2d();
else if (output == "lid") lid_panel_2d();
else if (output == "relief_test") relief_test();
else if (output == "fit_coupon") fit_coupon();
else if (output == "fit_check") fit_check();
else echo("Unknown output mode: ",output);