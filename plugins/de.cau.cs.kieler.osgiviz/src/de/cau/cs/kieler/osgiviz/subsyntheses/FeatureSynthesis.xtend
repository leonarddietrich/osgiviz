/*
 * OsgiViz - Kieler Visualization for Projects using the OSGi Technology
 * 
 * A part of OpenKieler
 * https://github.com/OpenKieler
 * 
 * Copyright 2019 by
 * + Christian-Albrechts-University of Kiel
 *   + Department of Computer Science
 *     + Real-Time and Embedded Systems Group
 * 
 * This code is provided under the terms of the Eclipse Public License (EPL).
 * See the file epl-v10.html for the license text.
 */
package de.cau.cs.kieler.osgiviz.subsyntheses

import com.google.inject.Inject
import de.cau.cs.kieler.klighd.kgraph.KGraphFactory
import de.cau.cs.kieler.klighd.kgraph.KNode
import de.cau.cs.kieler.klighd.krendering.extensions.KNodeExtensions
import de.cau.cs.kieler.klighd.syntheses.AbstractSubSynthesis
import de.cau.cs.kieler.osgiviz.OsgiStyles
import de.cau.cs.kieler.osgiviz.SynthesisUtils
import de.cau.cs.kieler.osgiviz.osgivizmodel.FeatureContext
import de.cau.cs.kieler.osgiviz.osgivizmodel.FeatureOverviewContext
import de.scheidtbachmann.osgimodel.Feature
import de.scheidtbachmann.osgimodel.OsgiProject
import java.util.EnumSet
import org.eclipse.elk.core.options.BoxLayouterOptions
import org.eclipse.elk.core.options.CoreOptions
import org.eclipse.elk.core.options.PortConstraints
import org.eclipse.elk.core.options.SizeConstraint
import org.eclipse.elk.core.util.BoxLayoutProvider.PackingMode

import static extension de.cau.cs.kieler.klighd.syntheses.DiagramSyntheses.*

/**
 * Sub-synthesis of {@link OsgiProject}s that handles expanded {@link Feature} views.
 * 
 * @author nre
 */
class FeatureSynthesis extends AbstractSubSynthesis<FeatureContext, KNode> {
    @Inject extension KNodeExtensions
    @Inject extension OsgiStyles
    @Inject BundleOverviewSynthesis bundleOverviewSynthesis
    extension KGraphFactory = KGraphFactory.eINSTANCE
        
    override transform(FeatureContext fc) {
        val feature = fc.modelElement
        return #[
            fc.createNode() => [
                addLayoutParam(CoreOptions::PORT_CONSTRAINTS, PortConstraints::FIXED_SIDE)
                associateWith(fc)
                data += createKIdentifier => [ it.id = fc.hashCode.toString ]
                
                // Show a bundle overview of all bundles provided by this feature.
                if (fc.bundleOverviewContext !== null) {
                    setLayoutOption(CoreOptions::NODE_SIZE_CONSTRAINTS, EnumSet.of(SizeConstraint.MINIMUM_SIZE))
                    SynthesisUtils.configureBoxLayout(it)
                    setLayoutOption(BoxLayouterOptions.BOX_PACKING_MODE, PackingMode.GROUP_MIXED)
                    val bundleOverviewNodes = bundleOverviewSynthesis.transform(
                        fc.bundleOverviewContext)
                    children += bundleOverviewNodes
                }
                
                // Add the rendering.
                val hasChildren = !children.empty
                addFeatureRendering(feature, fc.parent instanceof FeatureOverviewContext,
                    hasChildren, usedContext)
            ]
        ]
    }
    
}
