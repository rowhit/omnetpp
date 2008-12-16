/*--------------------------------------------------------------*
  Copyright (C) 2006-2008 OpenSim Ltd.
  
  This file is distributed WITHOUT ANY WARRANTY. See the file
  'License' for details on this and other legal matters.
*--------------------------------------------------------------*/

package org.omnetpp.ned.model.ex;

import java.util.Map;
import java.util.Set;

import org.omnetpp.ned.model.INEDElement;
import org.omnetpp.ned.model.interfaces.IMsgTypeElement;
import org.omnetpp.ned.model.interfaces.IMsgTypeInfo;
import org.omnetpp.ned.model.interfaces.ITypeElement;
import org.omnetpp.ned.model.pojo.ClassElement;

public class ClassElementEx extends ClassElement implements IMsgTypeElement {
    private IMsgTypeInfo typeInfo;

    protected ClassElementEx() {
        super();
    }

    protected ClassElementEx(INEDElement parent) {
        super(parent);
    }

    public IMsgTypeInfo getMsgTypeInfo() {
        if (typeInfo == null)
            typeInfo = getDefaultMsgTypeResolver().createTypeInfoFor(this);
        
        return typeInfo;
    }

    public String getFirstExtends() {
        String name = getExtendsName();
        
        if (name != null && !name.equals(""))
            return name;
        else
            return null;
    }

    public ITypeElement getFirstExtendsRef() {
        return getMsgTypeInfo().getFirstExtendsRef();
    }

    public Set<IMsgTypeElement> getLocalUsedTypes() {
        return getMsgTypeInfo().getLocalUsedTypes();
    }

    public Map<String, PropertyElementEx> getProperties() {
        return getMsgTypeInfo().getProperties();
    }
}
