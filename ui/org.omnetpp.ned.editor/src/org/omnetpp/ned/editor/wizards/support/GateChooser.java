package org.omnetpp.ned.editor.wizards.support;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.apache.commons.lang.StringUtils;
import org.eclipse.core.resources.IProject;
import org.eclipse.jface.viewers.ArrayContentProvider;
import org.eclipse.jface.viewers.ComboViewer;
import org.eclipse.jface.viewers.IStructuredSelection;
import org.eclipse.jface.viewers.StructuredSelection;
import org.eclipse.swt.SWT;
import org.eclipse.swt.layout.FillLayout;
import org.eclipse.swt.widgets.Composite;
import org.eclipse.swt.widgets.Text;
import org.omnetpp.common.wizard.CreationContext;
import org.omnetpp.common.wizard.IWidgetAdapterExt;
import org.omnetpp.ned.core.NEDResources;
import org.omnetpp.ned.core.NEDResourcesPlugin;
import org.omnetpp.ned.model.NEDElementConstants;
import org.omnetpp.ned.model.NEDTreeUtil;
import org.omnetpp.ned.model.ex.GateElementEx;
import org.omnetpp.ned.model.interfaces.IModuleKindTypeElement;
import org.omnetpp.ned.model.interfaces.INEDTypeInfo;
import org.omnetpp.ned.model.pojo.GateElement;

/**
 * A control for selecting a gate of a NED module type. If the module
 * exists, it lets the user select one of its gates from a combo;
 * if it doesn't, it lets the user enter a gate name.
 *
 * @author Andras
 */
public class GateChooser extends Composite implements IWidgetAdapterExt {
    public static final int INPUT = 1;
    public static final int OUTPUT = 2;
    public static final int INOUT = 4;
    public static final int VECTOR = 8;
    public static final int SCALAR = 16;

    // primary input
    private INEDTypeInfo nedType;
    private int filter = 0;

    // widgets
    private ComboViewer comboViewer;
    private Text text;
    
    // needed because we cannot get nedType in one step
    private IProject contextProject;
    private String nedTypeName;
    
    public GateChooser(Composite parent, int style) {
        super(parent, style);
        setLayout(new FillLayout());
        setNedType(null);
    }

    public void setGateFilter(int filter) {
        this.filter = filter;
        
        if (nedType != null)
            comboViewer.setInput(getMatchingGates());  // re-run filter
    }

    public int getGateFilter() {
        return filter;
    }

    public INEDTypeInfo getNedType() {
        return nedType;
    }

    public void setNedType(INEDTypeInfo nedType) {
        this.nedType = nedType;
        
        // create or fill the appropriate widget
        if (nedType == null) {
            if (comboViewer != null) {
                comboViewer.getCombo().dispose();
                comboViewer = null;
            }
            if (text == null)
                text = new Text(this, SWT.BORDER);
        }
        else {
            if (text != null) {
                text.dispose();
                text = null;
            }
            if (comboViewer == null) {
                comboViewer = new ComboViewer(this, SWT.READ_ONLY|SWT.BORDER);
                comboViewer.setContentProvider(new ArrayContentProvider());
                comboViewer.setLabelProvider(NEDTreeUtil.getNedModelLabelProvider());
            }
            
            // set/refresh gate list, and select 1st one
            List<GateElementEx> gates = getMatchingGates();
            comboViewer.setInput(gates);
            if (comboViewer.getSelection().isEmpty() && !gates.isEmpty())
                comboViewer.setSelection(new StructuredSelection(gates.get(0))); //FIXME this does not work, likely because GateElement has no hashCode() or equals()
        }
    }
    
    protected List<GateElementEx> getMatchingGates() {
        Map<String, GateElementEx> gateDecls = nedType.getGateDeclarations();
        List<GateElementEx> result = new ArrayList<GateElementEx>();
        for (GateElementEx gate : gateDecls.values())
            if (isMatching(gate))
                result.add(gate);
        return result;
    }

    protected boolean isMatching(GateElementEx gate) {
        // if either VECTOR or SCALAR is given, take getIsVector into account
        if ((filter & (VECTOR|SCALAR))!=0) {
            if (gate.getIsVector() && (filter & VECTOR)==0)
                return false;
            if (!gate.getIsVector() && (filter & SCALAR)==0)
                return false;
        }

        // if either INPUT, OUTPUT or INOUT is given, take gate direction into account
        if ((filter & (INPUT|OUTPUT|INOUT))!=0) {
            if (gate.getType()==NEDElementConstants.NED_GATETYPE_INPUT && (filter & INPUT)==0)
                return false;
            if (gate.getType()==NEDElementConstants.NED_GATETYPE_OUTPUT && (filter & OUTPUT)==0)
                return false;
            if (gate.getType()==NEDElementConstants.NED_GATETYPE_INOUT && (filter & INOUT)==0)
                return false;
        }
        return true;
    }

    public void setNedTypeName(String nedTypeName) {
        this.nedTypeName = nedTypeName;
        setNedType(lookupModuleType(nedTypeName, contextProject));
    }

    public String getGateName() {
        if (text != null) {
            return text.getText();
        }
        else if (comboViewer != null) {
            Object sel = ((IStructuredSelection)comboViewer.getSelection()).getFirstElement();
            return sel==null ? null : ((GateElement)sel).getName();
        }
        return null;
    }

    public void setGateName(String gateName) {
        if (text != null) {
            text.setText(gateName);
        }
        else if (comboViewer != null) {
            GateElement gate = nedType.getGateDeclarations().get(gateName);
            comboViewer.setSelection(new StructuredSelection(gate), true);
        }
    }

    /**
     * Adapter interface.
     */
    public void setValue(Object value, CreationContext context) {
        contextProject = context.getFolder().getProject();
        setNedType(lookupModuleType(nedTypeName, contextProject));
        setGateName(value.toString());
    }


    protected INEDTypeInfo lookupModuleType(String name, IProject project) {
        NEDResources nedResources = NEDResourcesPlugin.getNEDResources();
        if (project != null) {
            INEDTypeInfo nedType = nedResources.getToplevelNedType(name, project);
            if (nedType.getNEDElement() instanceof IModuleKindTypeElement)
                return nedType;
        }
        else {
            Set<INEDTypeInfo> nedTypes = nedResources.getNedTypesFromAllProjects(name);
            for (INEDTypeInfo nedType : nedTypes)
                if (nedType.getNEDElement() instanceof IModuleKindTypeElement)
                    return nedType;
        }
        return null;
    }

    /**
     * Adapter interface.
     */
    public Object getValue(CreationContext context) {
        return StringUtils.defaultString(getGateName());
    }

    public void setValue(Object value) {
        throw new IllegalAccessError("Call the 2-arg setValue instead");
    }

}
