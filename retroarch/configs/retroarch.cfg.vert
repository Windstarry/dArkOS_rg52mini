# dArkOS RK3562 — vertical (TATE) overlay, applied via `--appendconfig` (retroarch-tate).
# Controls rotated 90° to match the rotated screen. Only the keys below are overridden;
# everything else (physical d-pad, left stick, shoulders, etc.) comes from the main cfg.
#
# Raw joydev order (post 2026-06-21 compass-correct kernel):
#   b0=South(B)  b1=East(A)  b2=North(X)  b3=West(Y)
# Right-stick axes (post 1d80f0a L2-insertion migration): X=axis3 (+=right), Y=axis4 (+=down).
#
# Face buttons rotated: phys X->A(east), phys A->B(south), phys Y->X(north), phys B->Y(west).
input_player1_a_btn = "2"
input_player1_b_btn = "1"
input_player1_x_btn = "3"
input_player1_y_btn = "0"
#
# Right stick acts as the d-pad, rotated: stick-down=left, stick-left=up, stick-up=right, stick-right=down.
input_player1_left_axis = "+4"
input_player1_right_axis = "-4"
input_player1_up_axis = "-3"
input_player1_down_axis = "+3"
