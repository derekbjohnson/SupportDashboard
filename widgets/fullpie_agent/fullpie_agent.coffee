class Dashing.FullpieAgent extends Dashing.Widget

    @accessor 'data'

    onData: (data) ->
        #$(@node).fadeOut().fadeIn()
        @update(data.data)

    update: (dataSet) ->

        if !dataSet
            dataSet = @get("data")
        if !dataSet
            return

        # Remove any previous svg
        $(@node).children("svg").remove();

        # Config values here
        width = 750                             # Width of the SVG area
        height = 400                            # Height of the SVG area
        radius = Math.min(width, height) / 2    # Calculated min dimension of the SVG area
        radiuso = 130                           # Outer radius of the pie
        radiusi = 65                            # Inner radius of the pie (zero = pie, non-zero = donut)
        color = d3.scale.category20()           # Color scale for pie slices
        dropshadowx = 4                         # X-offset for drop shadow filter
        dropshadowy = 4                         # Y-offset for drop shadow filter
        dropshadowblur = "1.1"                  # [STRING] Blur value for drop shadow filter
        
        pie = d3.layout.pie().value((d) -> d.value)
        arc = d3.svg.arc().innerRadius(radiusi).outerRadius(radiuso)
        svg = d3.select(@node).append('svg').attr('width', width).attr('height', height).append('g').attr('transform', 'translate(' + width / 2 + ',' + height / 2 + ')')
        #console.log 'update pie', dataSet

        piedata = pie(dataSet)
        # Remove zero values from our pie data
        piedata = piedata.filter (pd) -> pd.value isnt 0
        #console.log 'update pie', piedata

        #create a marker element if it doesn't already exist
        defs = svg.select('defs')
        if defs.empty()
            defs = svg.append('defs')
        marker = defs.select('marker#circ')
        if marker.empty()
            defs.append('marker').attr('id', 'circ').attr('markerWidth', 44).attr('markerHeight', 44).attr('refX', 3).attr('refY', 3).append('circle').attr('cx', 3).attr('cy', 3).attr 'r', 3

        # Add drop shadow filter
        filter = defs.append("filter")
            .attr("id","dropshadow")
        filter.append("feGaussianBlur")
            .attr("in","SourceAlpha")
            .attr("stdDeviation",dropshadowblur)
            .attr("result","blur")
        filter.append("feOffset")
            .attr("in","blur")
            .attr("dx",dropshadowx)
            .attr("dy",dropshadowy)
            .attr("result","offsetBlur")
        feMerge = filter.append("feMerge")
        feMerge.append("feMergeNode")
            .attr("in","offsetBlur")
        feMerge.append("feMergeNode")
            .attr("in","SourceGraphic")

        # Create/select <g> elements to hold the different types of graphics
        # and keep them in the correct drawing order
        pathGroup = svg.select('g.piePaths')
        if pathGroup.empty()
            pathGroup = svg.append('g').attr('class', 'piePaths')
        pointerGroup = svg.select('g.pointers')
        if pointerGroup.empty()
            pointerGroup = svg.append('g').attr('class', 'pointers')
        labelGroup = svg.select('g.labels')
        if labelGroup.empty()
            labelGroup = svg.append('g').attr('class', 'labels')

        totalLabel = svg.select('g.totalLabel')
        if totalLabel.empty()
            totalLabel = svg.append('g').attr('class', 'totalLabel')

        path = pathGroup.selectAll('path.pie').data(piedata)
        path.enter().append('path').attr('class', 'pie').attr('fill', (d, i) -> color i)

        path.transition().duration(1500).attrTween('d', (d,i) ->
            `var i`
            theOldDataInPie = oldPieData
            # Interpolate the arcs in data space
            s0 = undefined
            e0 = undefined
            if theOldDataInPie[i]
                s0 = theOldDataInPie[i].startAngle
                e0 = theOldDataInPie[i].endAngle
            else if !theOldDataInPie[i] and theOldDataInPie[i - 1]
                s0 = theOldDataInPie[i - 1].endAngle
                e0 = theOldDataInPie[i - 1].endAngle
            else if !theOldDataInPie[i - 1] and theOldDataInPie.length > 0
                s0 = theOldDataInPie[theOldDataInPie.length - 1].endAngle
                e0 = theOldDataInPie[theOldDataInPie.length - 1].endAngle
            else
                s0 = 0
                e0 = 0
            i = d3.interpolate({
                startAngle: 0
                endAngle: 0
            },
                startAngle: d.startAngle
                endAngle: d.endAngle)
            (t) ->
                b = i(t)
                return arc b
        ).attr('filter','url(#dropshadow)')
        path.exit()
            .transition()
            .duration(300)
            .attrTween("d", (d,i) -> 
                `var i`
                s0 = 2 * Math.PI
                e0 = 2 * Math.PI
                i = d3.interpolate({
                    startAngle: d.startAngle
                    endAngle: d.endAngle
                },
                    startAngle: s0
                    endAngle: e0)
                (t) ->
                    b = i(t)
                    return arc b
            )
            .remove()

        labels = labelGroup.selectAll('text').data(piedata.sort((p1, p2) ->
            p1.startAngle - p2.startAngle
        ))
        #labels.enter().append('text').attr 'text-anchor', 'middle'
        labels.enter().append('text').attr('text-anchor', 'middle').attr("filter","url(#dropshadow)")
        labels.exit().remove()
        labelLayout = d3.geom.quadtree().extent([
            [
                -width
                -height
            ]
            [
                width
                height
            ]
        ]).x((d) ->
            d.x
        ).y((d) ->
            d.y
        )([])

        #create an empty quadtree to hold label positions
        maxLabelWidth = 0
        maxLabelHeight = 0
        labels.text((d) ->
            # Set the text *first*, so we can query the size
            # of the label with .getBBox()
            #d.value
            d.data.label
        ).each((d, i) ->
            # Move all calculations into the each function.
            # Position values are stored in the data object 
            # so can be accessed later when drawing the line
            ### calculate the position of the center marker ###
            a = (d.startAngle + d.endAngle) / 2

            #trig functions adjusted to use the angle relative
            #to the "12 o'clock" vector:
            d.cx = Math.sin(a) * (radiuso - (radiuso - radiusi) / 2)
            d.cy = -Math.cos(a) * (radiuso - (radiuso - radiusi) / 2)

            ### calculate the default position for the label,
               so that the middle of the label is centered in the arc
            ###
            bbox = @getBBox()
            #bbox.width and bbox.height will 
            #describe the size of the label text
            labelRadius = radius - 20
            d.x = Math.sin(a) * labelRadius
            d.l = d.x - bbox.width / 2 - 2
            d.r = d.x + bbox.width / 2 + 2
            d.y = -Math.cos(a) * (labelRadius)
            d.b = d.oy = d.y + 5
            d.t = d.y - bbox.height - 5

            ### check whether the default position 
               overlaps any other labels
            ###
            conflicts = []
            labelLayout.visit (node, x1, y1, x2, y2) ->
                #recurse down the tree, adding any overlapping 
                #node is the node in the quadtree, 
                #node.point is the value that we added to the tree
                #x1,y1,x2,y2 are the bounds of the rectangle that
                #this node covers

                if x1 > d.r + maxLabelWidth / 2 or x2 < d.l - maxLabelWidth / 2 or y1 > d.b + maxLabelHeight / 2 or y2 < d.t - maxLabelHeight / 2
                    return true # don't bother visiting children or checking this node
                p = node.point
                v = false
                h = false
                if p
                    #p is defined, i.e., there is a value stored in this node
                    h = p.l > d.l and p.l <= d.r or p.r > d.l and p.r <= d.r or p.l < d.l and p.r >= d.r
                    #horizontal conflict
                    v = p.t > d.t and p.t <= d.b or p.b > d.t and p.b <= d.b or p.t < d.t and p.b >= d.b
                    #vertical conflict
                    if h and v
                        conflicts.push p
                    #add to conflict list
                return

            if conflicts.length
                console.log d, ' conflicts with ', conflicts
                rightEdge = d3.max(conflicts, (d2) ->
                    `var maxLabelHeight`
                    `var maxLabelWidth`
                    d2.r
                )
                d.l = rightEdge
                d.x = d.l + bbox.width / 2 + 5
                d.r = d.l + bbox.width + 10
            else
                console.log 'no conflicts for ', d
            ### add this label to the quadtree, so it will show up as a conflict
               for future labels.  
            ###
            labelLayout.add d
            maxLabelWidth = Math.max(maxLabelWidth, bbox.width + 10)
            maxLabelHeight = Math.max(maxLabelHeight, bbox.height + 10)
            return
        )
        .transition()
        .attr('x', (d) ->
            d.x
        ).attr 'y', (d) ->
            d.y

        pointers = pointerGroup.selectAll('path.pointer').data(piedata)
        pointers.enter()
            .append('path')
            .attr('class', 'pointer')
            .style('fill', 'none')
            .style('stroke', 'black')
            .attr('marker-end', 'url(#circ)')
        pointers.exit().remove()
        pointers.transition().attr 'd', (d) ->
            if d.cx > d.l
                'M' + (d.l + 2) + ',' + d.b + 'L' + (d.r - 2) + ',' + d.b + ' ' + d.cx + ',' + d.cy
            else
                'M' + (d.r - 2) + ',' + d.b + 'L' + (d.l + 2) + ',' + d.b + ' ' + d.cx + ',' + d.cy

        totalTickets = 0
        for pd in dataSet
            totalTickets += pd.value
        #console.log totaltickets
        totalLabel.append('text')
            .text(totalTickets)
            .attr('text-anchor', 'middle')
            .attr('alignment-baseline', 'central')
            .attr('filter','url(#dropshadow)')

        oldPieData = piedata
        return
