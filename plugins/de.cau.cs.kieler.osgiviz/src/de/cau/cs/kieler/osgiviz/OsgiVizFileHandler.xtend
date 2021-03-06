package de.cau.cs.kieler.osgiviz

import com.google.inject.Injector
import de.cau.cs.kieler.klighd.IAction.ActionContext
import de.cau.cs.kieler.klighd.ViewContext
import de.cau.cs.kieler.osgiviz.osgivizmodel.OsgiViz
import de.cau.cs.kieler.osgiviz.osgivizmodel.OsgivizmodelFactory
import de.cau.cs.kieler.osgiviz.osgivizmodel.OsgivizmodelPackage
import de.scheidtbachmann.osgimodel.OsgiProject
import de.scheidtbachmann.osgimodel.OsgimodelPackage
import java.nio.file.Files
import java.nio.file.Paths
import java.text.SimpleDateFormat
import java.util.Collections
import java.util.Date
import java.util.List
import org.eclipse.elk.core.data.LayoutMetaDataService
import org.eclipse.elk.core.service.ILayoutConfigurationStore
import org.eclipse.elk.core.service.LayoutConfigurationManager
import org.eclipse.elk.core.service.LayoutConnectorsService
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.emf.ecore.resource.impl.ResourceSetImpl
import org.eclipse.emf.ecore.util.EcoreUtil.Copier
import org.eclipse.emf.ecore.xmi.impl.XMIResourceFactoryImpl

import static extension de.cau.cs.kieler.osgiviz.osgivizmodel.util.ContextExtensions.*

/**
 * Writes to and reads from a temporary file, which contains the current {@link OsgiViz}.
 * It is used to keep the visualization contexts state as long as the virtual machine is running.
 * 
 * @author ldi
 */
abstract class OsgiVizFileHandler {
	
	static URI tempDirURI = null;
	
	/**
	 * TODO: deleteOnExits() cannot remove the temp folder, possibly because the folder is not empty.
	 * <p>
	 * create a temporary folder for this session and stores the URI in tempDirURI
	 */
	def static createTempFolder(){
		val systempTempPath = Paths.get(System.getProperty("java.io.tmpdir"))
		val tempPath = Files.createTempDirectory(systempTempPath, "osgiviz");
		tempPath.toFile().deleteOnExit();
		// yes, this is necessary
		tempDirURI = URI.createURI(tempPath.toUri().toString())
//		System.out.println(tempDirURI)
	}
	
	/**
	 * @param viewContext
	 *  a {@link ViewContext} to read the input file URI from
	 * @return the temporary file name
	 */	
	def static String getSourceFileName(ViewContext viewContext){
		val obj = viewContext.getInputModel() as EObject
		val URI uri = obj.eResource.URI
		val fileName = uri.lastSegment().replace('.', '')
		return fileName
	}
	
	/**
	 * TODO: OsgiViz.modelElement loaded contains nothing but a URI to the model.
	 * <p>
	 * Reads and returns a OsgiViz from the related temp file, if it exists.
	 * 
	 * @param name
	 * 		for constructing the URI to load
	 * @return a {@link OsgiViz} or null, if no file exists for the given name
	 */
	def static OsgiViz getOsgivizFromTempFile(String name){
		if (tempDirURI === null) return null
		val emfURI = tempDirURI.appendSegment(name)
		
		val resSet = new ResourceSetImpl
		// check if a file at that URI exists
		if(resSet.getURIConverter().exists(emfURI, null)){
			val res = resSet.createResource(emfURI)		
			res.load(Collections.EMPTY_MAP)
			
			// (?!) for some reasons getContents() returns also some null elements
			val iterator = res.getContents().iterator()
			while(iterator.hasNext()){
				val checkOsgiViz = iterator.next() as OsgiViz
				if (checkOsgiViz !== null) return checkOsgiViz
			}	
		}
		return null
	}
	
	/**
	 * TODO: context.activeViewer.viewContext vs context.viewContext
	 * <p>
	 * TODO: check if there is a better way to store this model
	 * <p>
	 * (over)writes the current OsgiViz into the (temp) file.
	 * 
	 * @param context
	 *  	an {@link ActionContext}
     * @param isTemp
     *      a boolean. File is saved in a temporary directory (always the same file) if true and 
     *      next to original (always a new file) if false.
	 */
	def static writeCurrentModelToFile (ActionContext context, boolean isTemp) {
		if (isTemp && tempDirURI === null) createTempFolder()
		
		try {
		    // Get the currently viewed model from the context.
            val int index = context.viewContext.getProperty(OsgiSynthesisProperties.CURRENT_VISUALIZATION_CONTEXT_INDEX)
            val List<OsgiViz> contexts = context.viewContext.getProperty(OsgiSynthesisProperties.VISUALIZATION_CONTEXTS)
            val OsgiViz currentContext = contexts.get(index)

            // Also get the osgimodel referred by the osgiviz and store that as well.
            val OsgiViz rootContext = currentContext.rootVisualization
            val OsgiProject rootModel = rootContext?.modelElement
        
            // Take a copy of the context and model first to not mess up the current resource they might be stored in.
            val Copier copier = new Copier(true, true)
            val OsgiProject copiedModel = copier.copy(rootModel) as OsgiProject
            val OsgiViz copiedRoot = copier.copy(rootContext) as OsgiViz
            val copiedContext = 
                if (currentContext === rootContext) { copiedRoot } 
                else { copier.copy(currentContext) as OsgiViz }
            copier.copyReferences
        
            // Persist the current state of KLighD's synthesis options in the model...
            // ...the synthesis options
            storeSynthesisOptions(copiedRoot, context.activeViewer.viewContext)
            // ...and the layout options
            storeLayoutOptions(copiedRoot, context.activeViewer.viewContext)
        
            // Store the model.
            val r = Resource.Factory.Registry.INSTANCE
            val extensionFactories = r.getExtensionToFactoryMap
            val osgivizFileEnding = "osgiviz"
            val modelFileEnding = "model"
            extensionFactories.put(osgivizFileEnding, new XMIResourceFactoryImpl)
            extensionFactories.put(modelFileEnding, new XMIResourceFactoryImpl)
            val resSet = new ResourceSetImpl
            resSet.packageRegistry.put(OsgivizmodelPackage.eNS_URI, OsgivizmodelPackage.eINSTANCE)
            resSet.packageRegistry.put(OsgimodelPackage.eNS_URI, OsgimodelPackage.eINSTANCE)
        
            // build URI for osgiviz file
            var URI writeURI
            if (isTemp){
                val sourceName = getSourceFileName(context.viewContext)
		        writeURI = tempDirURI
		        writeURI = writeURI.appendSegment(sourceName)
            } else {
                writeURI = rootModel.eResource().getURI().trimSegments(1)
                val projectName = rootModel.projectName
                val timeStamp = new SimpleDateFormat("yyyyMMddHHmmss").format(new Date) 
                val fileName = projectName + "-visualization-" + timeStamp + "." + osgivizFileEnding 	
       	        writeURI = writeURI.appendSegment(fileName)
            }
            // prepare Resource
            val res = resSet.createResource(writeURI)
            res.getContents().add(copiedContext)
		
            // A resource to hold the original model to reference to while saving
		    val osgiModelRes = resSet.createResource(rootModel.eResource().getURI())
            osgiModelRes.getContents().add(copiedModel)
		
            // Save the content.
            res.save(Collections.EMPTY_MAP)
//            System.out.println("File stored successfully in " + writeURI)
        } catch (Throwable t) {
        	
        }
	}
	
	/**
     * Stores the currently used synthesis options in the visualization context.
     * 
     * @param visualizationContext The context to save the current options to.
     * @param viewContext The view context used to display the current diagram.
     */
    protected def static void storeSynthesisOptions(OsgiViz visualizationContext, ViewContext viewContext) {
        val synthesisOptions = viewContext.displayedSynthesisOptions
        visualizationContext.synthesisOptions.clear
        for (option : synthesisOptions) {
            val storedOption = OsgivizmodelFactory.eINSTANCE.createOption => [
                id = option.id
                value = viewContext.getOptionValue(option).toString
            ]
            visualizationContext.synthesisOptions.add(storedOption)
        }
    }
    
    /**
     * Stores the currently used layout options in the visualization context.
     * 
     * @param visualizationContext The context to save the current options to.
     * @param viewContext The view context used to display the current diagram.
     */
    protected def static void storeLayoutOptions(OsgiViz visualizationContext, ViewContext viewContext) {
        val layoutOptions = viewContext.displayedLayoutOptions
        visualizationContext.layoutOptions.clear
        // We need to obtain the LayoutConfigurationManager responsible for the view context to get
        // the current options.
        
        // This works in Eclipse-mode, but not in standalone-mode, as the returned injector is null
        // This is because no org.eclipse.elk.core.service.layoutConnectors can be registered without a running 
        // platform and Eclipse extension points (or so it seems).
        // I probably need to find a way to correctly register everything from ELK in non-Eclipse-mode and also use that
        // to configure the options in the LSP; currently that stores the layout config itself and does not use any ELK
        // stuff for that.
        // See ELK Issue #719 for details https://github.com/eclipse/elk/issues/719
        try {
            val Injector injector = LayoutConnectorsService.instance.getInjector(null, viewContext)
            val LayoutConfigurationManager layoutConfigManager = injector.getInstance(LayoutConfigurationManager)
            val ILayoutConfigurationStore.Provider layoutConfigStoreProvider =
                injector.getInstance(ILayoutConfigurationStore.Provider)
            for (option : layoutOptions) {
                val optionData = LayoutMetaDataService.instance.getOptionData(option.first.id)
                val layoutConfigStore =
                    layoutConfigStoreProvider.get(viewContext.diagramWorkbenchPart, viewContext.viewModel)
                val optionValue = layoutConfigManager.getOptionValue(optionData, layoutConfigStore)
                val storedOption = OsgivizmodelFactory.eINSTANCE.createOption => [
                    id = option.first.id
                    value = optionValue.toString
                ]
                visualizationContext.layoutOptions.add(storedOption)
            }
        } catch (Throwable t) {
            // Continue without storing the layout options, but log it on the console for now.
            println("Cannot store the layout options for this model:")
            t.printStackTrace
        }
    }
}
