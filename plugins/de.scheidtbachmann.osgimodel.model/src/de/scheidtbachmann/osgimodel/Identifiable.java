/**
 */
package de.scheidtbachmann.osgimodel;

import org.eclipse.emf.ecore.EObject;

/**
 * <!-- begin-user-doc -->
 * A representation of the model object '<em><b>Identifiable</b></em>'.
 * <!-- end-user-doc -->
 *
 * <!-- begin-model-doc -->
 * Basic Objects
 * <!-- end-model-doc -->
 *
 * <p>
 * The following features are supported:
 * </p>
 * <ul>
 *   <li>{@link de.scheidtbachmann.osgimodel.Identifiable#getEcoreId <em>Ecore Id</em>}</li>
 * </ul>
 *
 * @see de.scheidtbachmann.osgimodel.OsgimodelPackage#getIdentifiable()
 * @model abstract="true"
 * @generated
 */
public interface Identifiable extends EObject {
	/**
	 * Returns the value of the '<em><b>Ecore Id</b></em>' attribute.
	 * <!-- begin-user-doc -->
	 * <!-- end-user-doc -->
	 * @return the value of the '<em>Ecore Id</em>' attribute.
	 * @see #setEcoreId(String)
	 * @see de.scheidtbachmann.osgimodel.OsgimodelPackage#getIdentifiable_EcoreId()
	 * @model id="true"
	 * @generated
	 */
	String getEcoreId();

	/**
	 * Sets the value of the '{@link de.scheidtbachmann.osgimodel.Identifiable#getEcoreId <em>Ecore Id</em>}' attribute.
	 * <!-- begin-user-doc -->
	 * <!-- end-user-doc -->
	 * @param value the new value of the '<em>Ecore Id</em>' attribute.
	 * @see #getEcoreId()
	 * @generated
	 */
	void setEcoreId(String value);

} // Identifiable
