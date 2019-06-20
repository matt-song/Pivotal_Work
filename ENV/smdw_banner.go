package main

import (
    "fmt"
)





func main() {

    lightblue := "\033[38;5;6m"
    green := "\033[38;5;40m"
    normal := "\033[39;49m"

    title := "
\ \      / /__| | ___ ___  _ __ ___   ___  | |_ ___    ___ _ __ ___   __| |_      __
 \ \ /\ / / _ \ |/ __/ _ \| '_ ` _ \ / _ \ | __/ _ \  / __| '_ ` _ \ / _` \ \ /\ / /
  \ V  V /  __/ | (_| (_) | | | | | |  __/ | || (_) | \__ \ | | | | | (_| |\ V  V /
   \_/\_/ \___|_|\___\___/|_| |_| |_|\___|  \__\___/  |___/_| |_| |_|\__,_| \_/\_/
"
    fmt.Printf("%s%s%s", lightblue, title, normal )



}
/*


func printColor(logLevel string, message string){

    // define the color code here:
    lightRed := "\033[38;5;9m"
    red := "\033[38;5;1m"
    green := "\033[38;5;2m"
    yellow := "\033[38;5;3m"
    cyan := "\033[38;5;14m"
    //darkBlue := "\033[38;5;25m"
    normal := "\033[39;49m"

    var colorCode string
    
    switch logLevel {
    case "INFO":
        colorCode = green
    case "WARN":
        colorCode = yellow
    case "ERROR":
        colorCode = lightRed
    case "FATAL":
        colorCode = red
    case "DEBUG":
        colorCode = cyan
    default:
        colorCode = normal
    }
    fmt.Printf("%s[%s] %s%s", colorCode, logLevel, message,normal)
}

func printDEBUG(message string){
    if DEBUG == 1 {
        printColor("DEBUG", message + "\n")
    }
}
func printWARN(message string) {
    printColor("WARN", message + "\n")
}
func printERROR(err error, message string){
    printColor("ERROR", message + "\n")
    printColor("ERROR", "The error is [" + err.Error() + "]\n")
    os.Exit(1)
}
func printFATAL(err error, message string){
    printColor("FATAL", message + "\n")
    printColor("FATAL", "The error is [" + err.Error() + "]\n")
    os.Exit(1)
}
func printINFO(message string) {
    printColor("INFO", message + "\n")
}
*/