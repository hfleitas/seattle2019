import sys;
import os;
import platform;
if platform.system() == 'Windows':
    try:
        base_prefix = sys.base_prefix
        pathdirs = [os.path.normpath(os.path.normcase(x)) for x in os.environ['PATH'].split(';') if x.strip() != '']
        bindirs = [os.path.normpath(os.path.normcase(os.path.join(base_prefix, x))) for x in [r"Library\mingw-w64\bin", r"Library\usr\bin", r"Library\bin", r"Scripts", r"bin", r"condabin"] ]
        adddirs = [x for x in bindirs if x not in pathdirs]
        if adddirs:
            os.environ['PATH'] = os.environ['PATH'].strip(" \t\n\r;") + ";" + ';'.join(adddirs)
    except Exception as e:
        print("WARNING: sitecustomize: failed to update path, numpy may fail to load, exception={}".format(e))