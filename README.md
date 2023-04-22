#  ![Frame 8](https://user-images.githubusercontent.com/6630660/212826788-9eeab669-783c-472b-98ed-ee049984cc19.png) FastCopy

A GUI wrapper for Windows' built-in `robocopy` ~~and `xcopy`~~.

## Features
- Easy to use copy/paste/move/delete dialog, just like your good old explorer, but much faster🚀

- Support the new Windows 11 context menu, and the old windows context menu, with the fluent design icon adapted to Light/Dark theme

![](Screenshots/NewMenuCopy_Dark.png)
![](Screenshots/NewMenuCopy_Light.png)
![](Screenshots/NewMenuPaste_Dark.png)
![](Screenshots/OldMenuCopy_Dark.png)

- Multi-language support
  + English
  + Chinese


## Development
### Project structure
```
FastCopy
    FastCopy\               --- Main project
    FastCopyShellExtension\ --- A dll project for registering the new Windows context menu
    SpeedTest\              --- A speed test project for measuring various copying method under Windows
    UnitTest\               --- Unit test for above projects
    FastCopy.sln            --- The solution file for all the projects
```
### Build pre-requisites
- Visual Studio 2019+, with C++20 support
- Windows App Sdk, with C++ template

![image](https://user-images.githubusercontent.com/6630660/212826364-28155c87-c809-4ab8-b203-c8438fa64749.png)

![image](https://user-images.githubusercontent.com/6630660/212826583-75744773-2f10-45a7-8e5d-281ab1f9eee3.png)
