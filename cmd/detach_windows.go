package main

import (
	"os"
	"os/exec"
	"syscall"

	"golang.org/x/sys/windows"
)

func prepareLaunch() bool {
	if os.Getenv("POS_CHILD") == "1" || os.Getenv("POS_NO_DETACH") == "1" {
		return false
	}
	autostart := os.Getenv("POS_AUTOSTART") == "1"
	for _, arg := range os.Args[1:] {
		if arg == "--autostart" {
			autostart = true
			break
		}
	}
	exe, err := os.Executable()
	if err != nil {
		return false
	}
	cmd := exec.Command(exe, os.Args[1:]...)
	cmd.Env = append(os.Environ(), "POS_CHILD=1")
	cmd.SysProcAttr = &syscall.SysProcAttr{
		CreationFlags: windows.CREATE_NEW_PROCESS_GROUP | windows.DETACHED_PROCESS,
		HideWindow:    true,
	}
	if err := cmd.Start(); err != nil {
		return false
	}
	if autostart {
		os.Exit(0)
	}
	select {}
	return true
}
