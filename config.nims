import std/strutils

task compileOzz, "compile ozz animation source":
  exec "em++.bat -emit-llvm -std=c++17 -c -I.\\thirdparty\\ozz-animation\\include .\\thirdparty\\ozz-animation\\.build\\src_fused\\ozz_base.cc  -o.\\thirdparty\\ozz-animation\\.build\\src_fused\\ozz_base.bc"
  exec "em++.bat -emit-llvm -std=c++17 -c -I.\\thirdparty\\ozz-animation\\include .\\thirdparty\\ozz-animation\\.build\\src_fused\\ozz_animation.cc -o.\\thirdparty\\ozz-animation\\.build\\src_fused\\ozz_animation.bc"
  exec "em++.bat -emit-llvm -std=c++17 -c -I.\\thirdparty\\ozz-animation\\include -I.\\thirdparty\\ozz-animation\\samples\\framework .\\thirdparty\\ozz-animation\\samples\\framework\\mesh.cc -o.\\thirdparty\\ozz-animation\\.build\\src_fused\\mesh.bc"
  exec "em++.bat -emit-llvm -std=c++17 -c -I.\\thirdparty\\sokol-nim\\src\\sokol\\c -I.\\thirdparty\\ozz-animation\\include -I.\\thirdparty\\ozz-animation\\samples -I.\\thirdparty\\ozz-util .\\thirdparty\\ozz-util\\ozz_util.cc -o.\\thirdparty\\ozz-util\\ozz_util.bc"

task linkOzz, "link ozz animation library":
  exec """
  emar.bat rcu .\\thirdparty\\ozz.a
  C:\\Users\\Zach\\dev\\arkana\\thirdparty\\ozz-animation\\.build\\src_fused\\ozz_base.bc
  C:\\Users\\Zach\\dev\\arkana\\thirdparty\\ozz-animation\\.build\\src_fused\\ozz_animation.bc
  C:\\Users\\Zach\\dev\\arkana\\thirdparty\\ozz-animation\\.build\\src_fused\\mesh.bc
  C:\\Users\\Zach\\dev\\arkana\\thirdparty\\ozz-util\\ozz_util.bc
  """.unindent().replace("\n", " ")
