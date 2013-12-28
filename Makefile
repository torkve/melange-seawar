BINARY = seawar

MOCML ?= mocml
MOC ?= $(shell qmake -query QT_INSTALL_BINS)/moc
SPLC ?= splc
MPLC ?= mplc
CXX ?= g++
PKG_CONFIG_PATH ?= ~/workspace/qt5/qtbase/lib/pkgconfig
LD_LIBRARY_PATH ?= ~/workspace/qt5/qtbase/lib/
PATH := ~/workspace/qt5/qtbase/bin:$(PATH)

INCLUDES = -I ~/workspace/melange/tools/mpl/ -I $(shell ocamlfind query lablqml) -I +threads
BUILDFLAGS=-w -23 -verbose -g $(INCLUDES) -thread
LINKLIBS=lablqml.cmxa str.cmxa unix.cmxa threads.cmxa mpl_stdlib.cmx

CXXFLAGS = -I$(shell ocamlfind query lablqml) \
		   -I. \
		   $(shell pkg-config --cflags Qt5Core) \
		   -I$(shell ocamlc -where) \
		   -g -fPIC -std=c++11 -Dprotected=public -Dprivate=public \
		   -L$(shell ocamlc -where) \
		   -L$(shell ocamlc -where)/threads \
		   -L$(shell ocamlfind query lablqml)

LDFLAGS = -lthreads -lasmrun -lunix -lcamlstr -lstdc++ -llablqml_stubs $(shell pkg-config --libs Qt5Quick) $(shell pkg-config --libs Qt5OpenGL) -lm -ldl -lpthread

GEN_ML  = BoardItem.ml BoardModel.ml GameController.ml
GEN_CMX = $(GEN_ML:.ml=.cmx)
MOC_CPP = $(addprefix moc_,$(GEN_CMX:.cmx=_c.cpp))
GEN_CPP = $(GEN_CMX:.cmx=_c.o) $(MOC_CPP:.cpp=.o)
GEN_MOC = $(GEN_CMX:.cmx=_c.cpp)

CMXWRAP = cmxwrap.o

.SUFFIXES: .cpp .h .o .ml .mli .cmi .cmo .cmx .mpl .spl .json .s
.PHONY: all depend clean
.DEFAULT:
	# do nothing

all: $(BINARY)

$(BINARY): $(CMXWRAP) $(GEN_CPP)
	$(CXX) -o $@ $(CXXFLAGS) $^ $(LDFLAGS)

depend: $(GEN_CMX)
	ocamlfind dep *.ml *.ml > .depend

$(CMXWRAP): proto.cmx message.cmx board.cmx protocol.cmx $(GEN_CMX) game.cmx ai.cmx gui.cmx main.cmx
	ocamlopt -output-obj -dstartup $(INCLUDES) $(LINKLIBS) $^ -thread -linkall -o $@

message.ml: message.mpl
	$(MPLC) -s $^ > $@
	
protocol.ml protocol.mli proto.ml: protocol.spl
	$(SPLC) -v -t ocaml -s proto $^

moc_%.cpp: %.h
	$(MOC) $^ > $@

%.ml %.cpp %.h: input.json
	$(MOCML) input.json

.mli.cmi:
	ocamlopt $^

.ml.cmx:
	[ ! -f $<i ] || ocamlopt $(BUILDFLAGS) $<i
	ocamlopt -c $(BUILDFLAGS) $^

.cpp.o:
	$(CXX) -c $(CXXFLAGS) -o $@ $^

clean:
	rm -f *.cm[ioax] *.[ohs] *.cpp \
		a.out seawar \
		generated \
		message.ml proto.ml protocol.ml protocol.mli \
		$(GEN_ML)
