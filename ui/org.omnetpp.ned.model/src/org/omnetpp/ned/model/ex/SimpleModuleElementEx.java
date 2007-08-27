package org.omnetpp.ned.model.ex;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import org.omnetpp.ned.model.DisplayString;
import org.omnetpp.ned.model.INEDElement;
import org.omnetpp.ned.model.interfaces.IModuleTypeElement;
import org.omnetpp.ned.model.interfaces.INEDTypeInfo;
import org.omnetpp.ned.model.interfaces.INedTypeElement;
import org.omnetpp.ned.model.notification.NEDModelEvent;
import org.omnetpp.ned.model.pojo.ExtendsElement;
import org.omnetpp.ned.model.pojo.SimpleModuleElement;

/**
 * TODO add documentation
 *
 * @author rhornig
 */
public class SimpleModuleElementEx extends SimpleModuleElement implements IModuleTypeElement {

	private INEDTypeInfo typeInfo;
	protected DisplayString displayString = null;

    protected SimpleModuleElementEx() {
        init();
	}

    protected SimpleModuleElementEx(INEDElement parent) {
		super(parent);
        init();
	}

    private void init() {
        setName("Unnamed");
		typeInfo = getDefaultTypeResolver().createTypeInfoFor(this);
    }

    public INEDTypeInfo getNEDTypeInfo() {
    	return typeInfo;
    }

    @Override
    public void fireModelEvent(NEDModelEvent event) {
    	// invalidate cached display string because NED tree may have changed outside the DisplayString class
    	if (!NEDElementUtilEx.isDisplayStringUpToDate(displayString, this))
    		displayString = null;
    	super.fireModelEvent(event);
    }

    public DisplayString getDisplayString() {
    	if (displayString == null)
    		displayString = new DisplayString(this, NEDElementUtilEx.getDisplayStringLiteral(this));
    	displayString.setFallbackDisplayString(NEDElementUtilEx.displayStringOf(getFirstExtendsRef()));
    	return displayString;
    }

    // "extends" support
    public String getFirstExtends() {
        return NEDElementUtilEx.getFirstExtends(this);
    }

    public void setFirstExtends(String ext) {
        NEDElementUtilEx.setFirstExtends(this, ext);
    }

    public INedTypeElement getFirstExtendsRef() {
        return getNEDTypeInfo().getFirstExtendsRef();
    }

    public List<ExtendsElement> getAllExtends() {
        List<ExtendsElement> result = new ArrayList<ExtendsElement>();
        ExtendsElement extendsElement = getFirstExtendsChild();
        if (extendsElement == null)
            return result;

        for (INEDElement currChild : extendsElement)
            if (currChild instanceof ExtendsElement)
                result.add(extendsElement);

        return result;
    }

    // parameter query support
    public Map<String, ParamElementEx> getParamAssignments() {
        return getNEDTypeInfo().getParamAssignments();
    }

    public Map<String, ParamElementEx> getParamDeclarations() {
        return getNEDTypeInfo().getParamDeclarations();
    }

    // gate support
    public Map<String, GateElementEx> getGateSizes() {
        return getNEDTypeInfo().getGateSizes();
    }

    public Map<String, GateElementEx> getGateDeclarations() {
        return getNEDTypeInfo().getGateDeclarations();
    }

}
