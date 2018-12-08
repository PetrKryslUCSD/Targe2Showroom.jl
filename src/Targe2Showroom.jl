module Targe2Showroom

__precompile__(false)

using Targe2
using Printf
using DelimitedFiles
import Statistics: mean
using WriteVTK

function _makepyloadscript(file)
    pyfile = "loadscript.py"
    open(pyfile, "w") do fid
        println(fid, """
from paraview.simple import *
paraview.simple._DisableFirstRenderCameraReset()

# create a new 'XML Unstructured Grid Reader'
triangulation = XMLUnstructuredGridReader(FileName=['$(file).vtu'])

# find source
plotData1 = FindSource('PlotData1')

# get active view
renderView1 = GetActiveViewOrCreate('RenderView')
# uncomment following to set a specific view size
# renderView1.ViewSize = [400, 400]

# show data in view
triangulationDisplay = Show(triangulation, renderView1)

# trace defaults for the display properties.
triangulationDisplay.Representation = 'Surface'
triangulationDisplay.ColorArrayName = [None, '']
triangulationDisplay.OSPRayScaleFunction = 'PiecewiseFunction'
triangulationDisplay.SelectOrientationVectors = 'None'
triangulationDisplay.ScaleFactor = 20.0
triangulationDisplay.SelectScaleArray = 'None'
triangulationDisplay.GlyphType = 'Arrow'
triangulationDisplay.GlyphTableIndexArray = 'None'
triangulationDisplay.GaussianRadius = 1.0
triangulationDisplay.SetScaleArray = [None, '']
triangulationDisplay.ScaleTransferFunction = 'PiecewiseFunction'
triangulationDisplay.OpacityArray = [None, '']
triangulationDisplay.OpacityTransferFunction = 'PiecewiseFunction'
triangulationDisplay.DataAxesGrid = 'GridAxesRepresentation'
triangulationDisplay.SelectionCellLabelFontFile = ''
triangulationDisplay.SelectionPointLabelFontFile = ''
triangulationDisplay.PolarAxes = 'PolarAxesRepresentation'
triangulationDisplay.ScalarOpacityUnitDistance = 16.62540800220111

# init the 'GridAxesRepresentation' selected for 'DataAxesGrid'
triangulationDisplay.DataAxesGrid.XTitleFontFile = ''
triangulationDisplay.DataAxesGrid.YTitleFontFile = ''
triangulationDisplay.DataAxesGrid.ZTitleFontFile = ''
triangulationDisplay.DataAxesGrid.XLabelFontFile = ''
triangulationDisplay.DataAxesGrid.YLabelFontFile = ''
triangulationDisplay.DataAxesGrid.ZLabelFontFile = ''

# init the 'PolarAxesRepresentation' selected for 'PolarAxes'
triangulationDisplay.PolarAxes.PolarAxisTitleFontFile = ''
triangulationDisplay.PolarAxes.PolarAxisLabelFontFile = ''
triangulationDisplay.PolarAxes.LastRadialAxisTextFontFile = ''
triangulationDisplay.PolarAxes.SecondaryRadialAxesTextFontFile = ''

# reset view to fit data
renderView1.ResetCamera()

# update the view to ensure updated data information
renderView1.Update()

# change representation type
triangulationDisplay.SetRepresentationType('Surface With Edges')

# set scalar coloring
ColorBy(triangulationDisplay, ('CELLS', 'Regions'))

# Properties modified on triangulationDisplay
triangulationDisplay.EdgeColor = [1.0, 1.0, 0.4980392156862745]

# rescale color and/or opacity maps used to include current data range
triangulationDisplay.RescaleTransferFunctionToDataRange(True, False)

# show color bar/color legend
triangulationDisplay.SetScalarBarVisibility(renderView1, True)

# get color transfer function/color map for 'Regions'
regionsLUT = GetColorTransferFunction('Regions')

# Properties modified on xMLUnstructuredGridReader1Display.DataAxesGrid
triangulationDisplay.DataAxesGrid.GridAxesVisibility = 1

# show color bar/color legend
triangulationDisplay.SetScalarBarVisibility(renderView1, False)

# reset view to fit data
renderView1.ResetCamera()

# save screenshot
SaveScreenshot('$(file).png', renderView1, ImageResolution=[618, 603])
""")
    end
    return pyfile
end

function writevtk(filename, mesh)
    cells = MeshCell[]
    cdata = fill(0.0, size(mesh.triconn, 1))
    celltype = (size(mesh.triconn, 2) == 3) ? VTKCellTypes.VTK_TRIANGLE : VTKCellTypes.VTK_QUADRATIC_TRIANGLE
    for i = 1:size(mesh.triconn, 1)
        push!(cells, MeshCell(celltype, vec(view(mesh.triconn, i, :))))
    end
    for i = 1:length(mesh.trigroups)
        for j = 1:length(mesh.trigroups[i])
            t = mesh.trigroups[i][j]
            cdata[t] = i
        end
    end
    vtk = vtk_grid(filename, transpose(mesh.xy), cells)
    vtk_cell_data(vtk, cdata, "Regions")
    vtk_save(vtk)
    return true
end

function showmesh(filename, mesh)
    writevtk(filename, mesh)
    pyfile = _makepyloadscript(filename)
    @async run(`"paraview.exe" --script=$(pyfile)`)
    return
end

"""
    demo(filename, commands)

Generate a mesh Targe2 and show it with Paraview.
"""
function demo(filename, commands; show = false, kwargs...)
    mesh = targe2mesher(commands, kwargs...)
    show && showmesh(filename, mesh)
    return mesh
end

end
