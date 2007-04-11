package org.omnetpp.inifile.editor.editors;

import org.eclipse.core.resources.IFile;
import org.eclipse.core.resources.IMarker;
import org.eclipse.core.resources.IResourceChangeEvent;
import org.eclipse.core.resources.IResourceChangeListener;
import org.eclipse.core.resources.ResourcesPlugin;
import org.eclipse.core.runtime.IProgressMonitor;
import org.eclipse.jface.dialogs.ErrorDialog;
import org.eclipse.jface.dialogs.MessageDialog;
import org.eclipse.jface.text.IDocument;
import org.eclipse.jface.viewers.ISelection;
import org.eclipse.jface.viewers.ISelectionProvider;
import org.eclipse.jface.viewers.StructuredSelection;
import org.eclipse.swt.widgets.Control;
import org.eclipse.swt.widgets.Display;
import org.eclipse.ui.IEditorInput;
import org.eclipse.ui.IEditorPart;
import org.eclipse.ui.IEditorSite;
import org.eclipse.ui.IFileEditorInput;
import org.eclipse.ui.IPropertyListener;
import org.eclipse.ui.PartInitException;
import org.eclipse.ui.ide.IDE;
import org.eclipse.ui.ide.IGotoMarker;
import org.eclipse.ui.part.FileEditorInput;
import org.eclipse.ui.part.MultiPageEditorPart;
import org.eclipse.ui.views.contentoutline.IContentOutlinePage;
import org.omnetpp.common.ui.SelectionProvider;
import org.omnetpp.common.util.DelayedJob;
import org.omnetpp.inifile.editor.form.InifileFormEditor;
import org.omnetpp.inifile.editor.model.IInifileChangeListener;
import org.omnetpp.inifile.editor.model.InifileAnalyzer;
import org.omnetpp.inifile.editor.model.InifileConverter;
import org.omnetpp.inifile.editor.model.InifileDocument;
import org.omnetpp.inifile.editor.text.InifileTextEditor;
import org.omnetpp.inifile.editor.views.InifileContentOutlinePage;

/**
 * Editor for omnetpp.ini files.
 */
//FIXME File|Revert is always diabled; same for Redo/Undo
//XXX should listen on workspace changes (of included ini files)
public class InifileEditor extends MultiPageEditorPart implements IResourceChangeListener, IGotoMarker {
	/** The text editor */
	private InifileTextEditor textEditor;
	
	/** Form editor */
	private InifileFormEditor formEditor;

	/** The data model */
	private InifileEditorData editorData = new InifileEditorData();

	private InifileContentOutlinePage outlinePage;

	private DelayedJob postSelectionChangedJob;
	
	/**
	 * Creates the ini file editor.
	 */
	public InifileEditor() {
		super();
		ResourcesPlugin.getWorkspace().addResourceChangeListener(this);
	}
 
	public InifileEditorData getEditorData() {
		return editorData;
	}
	
	/**
	 * Creates the text editor page of the multi-page editor.
	 */
	void createTextEditorPage() {
		try {
			textEditor = new InifileTextEditor(this);
			int index = addPage(textEditor, getEditorInput());
			setPageText(index, "Text");
		} catch (PartInitException e) {
			ErrorDialog.openError(getSite().getShell(), "Error creating nested text editor", null, e.getStatus());
		}
	}

	/**
	 * Creates the pages of the multi-page editor.
	 */
	@Override
	protected void createPages() {
		// create form page
		formEditor = new InifileFormEditor(getContainer(), this);
		addEditorPage(formEditor, "Form");

		// create texteditor
		createTextEditorPage();
		
		// set up editorData (the InifileDocument)
		IFile file = ((IFileEditorInput)getEditorInput()).getFile();
		IDocument document = textEditor.getDocumentProvider().getDocument(getEditorInput());
		editorData.setInifiledocument(new InifileDocument(document, file));
		editorData.setInifileAnalyzer(new InifileAnalyzer(editorData.getInifileDocument()));

		// replace original MultiPageSelectionProvider with our own, as we want to
		// publish our own selection (with InifileSelectionItem) for both pages.
		getSite().setSelectionProvider(new SelectionProvider());
		
		// propagate property changes (esp. PROP_DIRTY) from our text editor
		textEditor.addPropertyListener(new IPropertyListener() {
			public void propertyChanged(Object source, int propertyId) {
				firePropertyChange(propertyId);
			}
		});
		
		// this DelayedJob will, after a delay, publish a new editor selection towards the workbench
		postSelectionChangedJob = new DelayedJob(600) {
			public void run() {
				updateSelection();
			}
		};
		
		// we want to update the selection whenever the document changes, or the cursor position in the text editor changes
		editorData.getInifileDocument().addInifileChangeListener(new IInifileChangeListener() {
			public void modelChanged() {
				postSelectionChangedJob.restartTimer();
			}
		});
		textEditor.setPostCursorPositionChangeJob(new Runnable() {
			public void run() {
				postSelectionChangedJob.restartTimer();
			}
		});
		
		// we want inifileAnalyzer to run whenever the document was parsed
		//XXX revise performance-wise (it doesn't have to run immediately)
		editorData.getInifileDocument().addInifileChangeListener(new IInifileChangeListener() {
			public void modelChanged() {
				editorData.getInifileAnalyzer().run();
			}
		});
		
		// if the file is in the old format, offer upgrading it
		convertOldInifile();
	}

	protected void updateSelection() {
		int cursorLine = textEditor.getCursorLine();
		String section = getEditorData().getInifileDocument().getSectionForLine(cursorLine);
		String key = getEditorData().getInifileDocument().getKeyForLine(cursorLine);
		System.out.println("Line: "+cursorLine+" section:"+section+" key="+key);
		setSelection(section, key);
	}

	/**
	 * Sets the editor's selection to an InifileSelectionItem containing
	 * the given section and key.
	 */
	public void setSelection(String section, String key) {
		ISelection selection = new StructuredSelection(new InifileSelectionItem(getEditorData().getInifileDocument(), getEditorData().getInifileAnalyzer(), section, key));
		ISelectionProvider selectionProvider = getSite().getSelectionProvider();
		selectionProvider.setSelection(selection);
	}

	/**
	 * Adds an editor page at the last position.
	 */
	public int addEditorPage(Control page, String label) {
		int index = addPage(page);
		setPageText(index, label);
		return index;
	}

	/**
	 * The <code>MultiPageEditorPart</code> implementation of this 
	 * <code>IWorkbenchPart</code> method disposes all nested editors.
	 * Subclasses may extend.
	 */
	@Override
	public void dispose() {
		ResourcesPlugin.getWorkspace().removeResourceChangeListener(this);
		if (outlinePage != null)
			outlinePage.setInput(null); //XXX ?
		((InifileDocument)editorData.getInifileDocument()).dispose();
		super.dispose();
	}

	/**
	 * Saves the multi-page editor's document.
	 */
	@Override
	public void doSave(IProgressMonitor monitor) {
		textEditor.doSave(monitor);
	}
	
	/**
	 * Saves the multi-page editor's document as another file.
	 * Also updates the text for page 0's tab, and updates this multi-page editor's input
	 * to correspond to the nested editor's.
	 */
	@Override
	public void doSaveAs() {
		textEditor.doSaveAs();
		setInput(textEditor.getEditorInput());
	}
	
	/* (non-Javadoc)
	 * Method declared on IGotoMarker
	 */
	public void gotoMarker(IMarker marker) {
		setActivePage(0); //XXX
		IDE.gotoMarker(textEditor, marker);
	}

	/**
	 * The <code>MultiPageEditorExample</code> implementation of this method
	 * checks that the input is an instance of <code>IFileEditorInput</code>.
	 */
	@Override
	public void init(IEditorSite site, IEditorInput editorInput) throws PartInitException {
		if (!(editorInput instanceof IFileEditorInput))
			throw new PartInitException("Invalid input: it must be a file in the workspace");
		super.init(site, editorInput);
		setPartName(editorInput.getName());
	}

	/* (non-Javadoc)
	 * Method declared on IEditorPart.
	 */
	@Override
	public boolean isSaveAsAllowed() {
		return true;
	}

	/**
	 * Notification about page change.
	 */
	@Override
	protected void pageChange(int newPageIndex) {
		super.pageChange(newPageIndex);
		if (getControl(newPageIndex) == formEditor) {
			formEditor.pageSelected();
		}
		else {
			formEditor.pageDeselected();
		}
	}

	/**
	 * Detect when the file is in the old format, and offer converting it.
	 */
	protected void convertOldInifile() {
		IDocument doc = textEditor.getDocumentProvider().getDocument(getEditorInput());
		if (InifileConverter.needsConversion(doc.get())) {
			if (MessageDialog.openQuestion(null, "Old Inifile Format", 
					"This inifile is in the old (3.x) format, and needs to be converted " +
					"into the new format. This includes renaming some sections and configuration keys. " +
					"Do you want to convert the editor contents now?")) {
				String newText = InifileConverter.convert(doc.get());
				doc.set(newText);
			}
		}
	}

	@Override
	public Object getAdapter(Class required) {
		if (IContentOutlinePage.class.equals(required)) {
			if (outlinePage == null) {
				outlinePage = new InifileContentOutlinePage(textEditor);
				outlinePage.setInput(getEditorData().getInifileDocument());
			}
			return outlinePage;
		}
		return super.getAdapter(required);
	}
	
	/**
	 * Called on workspace changes.
	 */
	public void resourceChanged(final IResourceChangeEvent event){
		// close editor on project close
		if (event.getType() == IResourceChangeEvent.PRE_CLOSE) {
			final IEditorPart thisEditor = this;
			Display.getDefault().asyncExec(new Runnable(){
				public void run(){
					if (((FileEditorInput)thisEditor.getEditorInput()).getFile().getProject().equals(event.getResource())) {
						thisEditor.getSite().getPage().closeEditor(thisEditor, true);
					}
				}            
			});
		}
	}
}
